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

        component = {
          name: class_name,
          file: relative,
          type: detect_component_type(content),
          props: extract_props(content),
          slots: extract_slots(content)
        }

        preview = find_preview(path, class_name)
        component[:preview] = preview if preview

        sidecar = find_sidecar_assets(path)
        component[:sidecar_assets] = sidecar if sidecar.any?

        component
      end

      def extract_class_name(content)
        match = content.match(/class\s+(\w+)/)
        match[1] if match
      end

      def detect_component_type(content)
        if content.match?(/< (ViewComponent::Base|ApplicationComponent)/)
          :view_component
        elsif content.match?(/< (Phlex::HTML|Phlex::SVG|ApplicationView|ApplicationComponent)/) &&
              content.match?(/def (view_)?template/)
          :phlex
        else
          :unknown
        end
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
        if content.match?(/< Phlex/)
          content.scan(/def\s+(\w+)\s*\(\s*&\s*\w*\s*\)/).each do |name,|
            next if %w[initialize template view_template before_template after_template].include?(name)
            slots << { name: name, type: :phlex_slot }
          end
        end

        slots
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
