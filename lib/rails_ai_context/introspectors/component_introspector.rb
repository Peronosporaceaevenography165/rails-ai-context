# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Discovers ViewComponent and Phlex components: class definitions,
    # slots, props, previews, and sidecar assets.
    class ComponentIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call
        {
          components: extract_components,
          summary: build_summary
        }
      rescue => e
        { error: e.message }
      end

      private

      def root
        app.root.to_s
      end

      def components_dir
        File.join(root, "app/components")
      end

      def extract_components
        return [] unless Dir.exist?(components_dir)

        Dir.glob(File.join(components_dir, "**/*.rb")).filter_map do |path|
          next if path.end_with?("_preview.rb")
          next if File.basename(path) == "application_component.rb"

          parse_component(path)
        rescue => e
          { file: path.sub("#{root}/", ""), error: e.message }
        end.sort_by { |c| c[:name] || "" }
      end

      def parse_component(path)
        content = File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace)
        relative = path.sub("#{root}/", "")
        class_name = extract_class_name(content)
        return nil unless class_name

        props = extract_props(content)
        enum_values = extract_enum_values(content)
        attach_enum_values_to_props(props, enum_values, content)

        component = {
          name: class_name,
          file: relative,
          type: detect_component_type(content),
          props: props,
          slots: extract_slots(content)
        }

        preview = find_preview(path, class_name)
        component[:preview] = preview if preview

        sidecar = find_sidecar_assets(path)
        component[:sidecar_assets] = sidecar if sidecar.any?

        component
      end

      def extract_class_name(content)
        # Extract fully qualified class name (e.g., Components::Articles::Article)
        match = content.match(/class\s+([\w:]+)/)
        return nil unless match

        full_name = match[1]
        # Return the last meaningful segment for display, but keep namespace context
        # e.g., "Components::Articles::Article" → "Articles::Article"
        #        "RubyUI::Button" → "Button"
        #        "AlertComponent" → "AlertComponent"
        parts = full_name.split("::")
        if parts.size > 2 && parts.first == "Components"
          parts[1..].join("::")
        elsif parts.size > 1 && %w[Components RubyUI].include?(parts.first)
          parts.last
        else
          full_name
        end
      end

      def detect_component_type(content)
        if content.match?(/< (ViewComponent::Base|ApplicationComponent)\b/)
          :view_component
        elsif content.match?(/< (Phlex::HTML|Phlex::SVG|ApplicationView|ApplicationComponent)\b/) ||
              (content.match?(/< \S+/) && inherits_from_phlex_base?(content))
          :phlex
        else
          :unknown
        end
      end

      def inherits_from_phlex_base?(content)
        parent_match = content.match(/class\s+\S+\s*<\s*(\S+)/)
        return false unless parent_match

        parent_class = parent_match[1]
        @phlex_bases ||= detect_phlex_bases
        @phlex_bases.include?(parent_class)
      end

      def detect_phlex_bases
        bases = Set.new
        return bases unless Dir.exist?(components_dir)

        Dir.glob(File.join(components_dir, "**/*.rb")).each do |path|
          content = File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace)
          if content.match?(/< (Phlex::HTML|Phlex::SVG)\b/)
            match = content.match(/class\s+(\S+)\s*</)
            bases << match[1] if match
          end
        end

        bases
      end

      def extract_props(content)
        # Extract from initialize method parameters
        init_match = content.match(/def initialize\(([^)]*)\)/m)
        return [] unless init_match

        params_str = init_match[1]
        props = []

        # Parse keyword arguments: name:, name: default
        params_str.scan(/(\w+):\s*([^,)]*)?/) do |name, default|
          prop = { name: name }
          default = default&.strip
          prop[:default] = default if default && !default.empty?
          props << prop
        end

        # Parse positional arguments
        params_str.scan(/\A\s*(\w+)(?:\s*=\s*([^,)]+))?/) do |name, default|
          next if props.any? { |p| p[:name] == name }
          prop = { name: name, positional: true }
          default = default&.strip
          prop[:default] = default if default && !default.empty?
          props << prop
        end

        props
      end

      def extract_slots(content)
        slots = []

        # renders_one :name, optional lambda/class
        content.scan(/renders_one\s+:(\w+)(?:,\s*(.+))?/) do |name, renderer|
          slot = { name: name, type: :one }
          slot[:renderer] = renderer.strip if renderer && !renderer.strip.empty?
          slots << slot
        end

        # renders_many :name, optional lambda/class
        content.scan(/renders_many\s+:(\w+)(?:,\s*(.+))?/) do |name, renderer|
          slot = { name: name, type: :many }
          slot[:renderer] = renderer.strip if renderer && !renderer.strip.empty?
          slots << slot
        end

        # Phlex slots: def slot_name(&block)
        if detect_component_type(content) == :phlex
          content.scan(/def\s+(\w+)\s*\(\s*&\s*\w*\s*\)/).each do |name,|
            next if %w[initialize template view_template before_template after_template].include?(name)
            slots << { name: name, type: :phlex_slot }
          end
        end

        slots
      end

      # Extracts enumerable values from constants and case statements.
      # Returns a hash mapping downcased constant/variable names to arrays of symbol values.
      # Detects three patterns:
      #   1. Hash constants: VARIANTS = { primary: "...", secondary: "..." } -> keys
      #   2. Array constants: SIZES = [:sm, :md, :lg] -> elements
      #   3. Case statements: case @variant; when :primary; when :secondary -> when values
      def extract_enum_values(content)
        enums = {}

        # Pattern 1: Hash constants — NAME = { key: "value", ... }
        content.scan(/([A-Z][A-Z_0-9]*)\s*=\s*\{([^}]*)\}/m) do |name, body|
          keys = body.scan(/(\w+):/).map(&:first)
          enums[name.downcase] = keys if keys.any?
        end

        # Pattern 2: Array constants — NAME = [:sym, :sym, ...]
        content.scan(/([A-Z][A-Z_0-9]*)\s*=\s*\[([^\]]*)\]/) do |name, body|
          values = body.scan(/:(\w+)/).map(&:first)
          enums[name.downcase] = values if values.any?
        end

        # Pattern 3: Case statements — case @ivar; when :val1 ... when :val2
        # Use a non-greedy match that stops at the next `end`, `case`, or `def` keyword
        content.scan(/case\s+@(\w+)\s*\n(.*?)(?=\n\s*(?:end|case|def)\b)/m) do |ivar, block|
          values = block.scan(/when\s+:(\w+)/).map(&:first)
          next if values.empty?
          # Merge with existing values for same ivar (handles multiple case blocks)
          existing = enums[ivar] || []
          enums[ivar] = (existing + values).uniq
        end

        enums
      end

      # Matches extracted enum values to props by:
      #   1. Direct ivar match: prop "variant" matches case @variant values
      #   2. Constant name match: prop "size" matches SIZES constant, prop "variant" matches VARIANTS constant
      #   3. Constant usage in initialize: @size referenced as SIZES[@size] matches prop "size"
      def attach_enum_values_to_props(props, enum_values, content)
        props.each do |prop|
          name = prop[:name]
          values = nil

          # Direct match: prop name matches case @ivar
          values = enum_values[name] if enum_values.key?(name)

          # Constant name match: prop "size" -> SIZES, prop "variant" -> VARIANTS/COLORS
          unless values
            # Try pluralized forms and common naming patterns
            candidates = [ name.upcase + "S", name.upcase + "ES", name.upcase ]
            candidates.each do |candidate|
              if enum_values.key?(candidate.downcase)
                values = enum_values[candidate.downcase]
                break
              end
            end
          end

          # Constant usage match: find CONST[@ivar] patterns in the file
          unless values
            content.scan(/([A-Z][A-Z_0-9]*)\[@#{name}\]/) do |const_name,|
              if enum_values.key?(const_name.downcase)
                values = enum_values[const_name.downcase]
                break
              end
            end
          end

          prop[:values] = values if values&.any?
        end
      end

      def find_preview(component_path, class_name)
        # Check common preview locations
        preview_name = class_name.sub(/Component\z/, "").underscore
        locations = [
          File.join(root, "spec/components/previews/#{preview_name}_component_preview.rb"),
          File.join(root, "test/components/previews/#{preview_name}_component_preview.rb"),
          File.join(root, "app/components/previews/#{preview_name}_component_preview.rb"),
          component_path.sub(/\.rb\z/, "_preview.rb")
        ]

        preview_path = locations.find { |p| File.exist?(p) }
        preview_path&.sub("#{root}/", "")
      end

      def find_sidecar_assets(component_path)
        # Sidecar files: same name with different extensions
        base = component_path.sub(/\.rb\z/, "")
        dir = File.dirname(component_path)
        stem = File.basename(base)

        assets = []

        # Direct sidecar: component_name.html.erb, component_name.css, etc.
        Dir.glob("#{base}.*").each do |path|
          next if path == component_path
          assets << File.basename(path)
        end

        # Sidecar directory: component_name/ with assets
        sidecar_dir = base
        if Dir.exist?(sidecar_dir) && File.directory?(sidecar_dir)
          Dir.glob(File.join(sidecar_dir, "*")).each do |path|
            assets << "#{File.basename(sidecar_dir)}/#{File.basename(path)}" if File.file?(path)
          end
        end

        assets.sort
      end

      def build_summary
        components = extract_components
        return {} if components.empty?

        types = components.group_by { |c| c[:type] }
        {
          total: components.size,
          view_component: types[:view_component]&.size || 0,
          phlex: types[:phlex]&.size || 0,
          with_slots: components.count { |c| c[:slots]&.any? },
          with_previews: components.count { |c| c[:preview] }
        }
      end
    end
  end
end
