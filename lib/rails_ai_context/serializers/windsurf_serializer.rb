# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .windsurfrules within Windsurf's hard 6,000 character limit.
    # Always produces compact output regardless of context_mode.
    class WindsurfSerializer
      include TestCommandDetection
      include StackOverviewHelper
      include DesignSystemHelper

      MAX_CHARS = 5_800 # Leave buffer below 6K limit

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call
        content = render
        # HARD enforce character limit — Windsurf silently truncates
        if content.length > MAX_CHARS
          content = content[0...MAX_CHARS]
          content += "\n\n# Use MCP tools for full details."
        end
        content
      end

      private

      def render
        lines = []
        lines << "# #{context[:app_name]} — Rails #{context[:rails_version]}"
        lines << ""

        # Stack (very compact)
        schema = context[:schema]
        lines << "Database: #{schema[:adapter]}, #{schema[:total_tables]} tables" if schema && !schema[:error]

        models = context[:models]
        lines << "Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        lines << "Routes: #{routes[:total_routes]}" if routes && !routes[:error]

        lines.concat(full_preset_stack_lines)

        # Gems (one line per category)
        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = gems[:notable_gems] || gems[:notable] || gems[:detected] || []
          grouped = notable.group_by { |g| g[:category]&.to_s || "other" }
          grouped.first(6).each do |cat, gem_list|
            lines << "#{cat}: #{gem_list.map { |g| g[:name] }.first(4).join(', ')}"
          end
        end

        lines << ""

        # Key models (names only — character budget is tight)
        if models.is_a?(Hash) && !models[:error] && models.any?
          lines << "# Key models"
          models.keys.sort.first(20).each do |name|
            data = models[name]
            lines << "- #{name}"
            scopes = (data[:scopes] || [])
            constants = (data[:constants] || [])
            if scopes.any? || constants.any?
              extras = []
              extras << "scopes: #{scopes.join(', ')}" if scopes.any?
              constants.each { |c| extras << "#{c[:name]}: #{c[:values].join(', ')}" }
              lines << "  #{extras.join(' | ')}"
            end
          end
          lines << "- ...#{models.size - 20} more" if models.size > 20
          lines << ""
        end

        # Architecture
        conv = context[:conventions]
        if conv.is_a?(Hash) && !conv[:error]
          arch = conv[:architecture] || []
          if arch.any?
            arch_labels = RailsAiContext::Tools::GetConventions::ARCH_LABELS rescue {}
            lines << "# Architecture"
            arch.first(5).each { |p| lines << "- #{arch_labels[p] || p}" }
          end
        end

        # List service objects
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          services_dir = File.join(root, "app", "services")
          if Dir.exist?(services_dir)
            service_files = Dir.glob(File.join(services_dir, "*.rb"))
              .map { |f| File.basename(f, ".rb").camelize }
              .reject { |s| s == "ApplicationService" }
            lines << "Services: #{service_files.join(', ')}" if service_files.any?
          end
        rescue; end

        # List jobs
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          jobs_dir = File.join(root, "app", "jobs")
          if Dir.exist?(jobs_dir)
            job_files = Dir.glob(File.join(jobs_dir, "*.rb"))
              .map { |f| File.basename(f, ".rb").camelize }
              .reject { |j| j == "ApplicationJob" }
            lines << "Jobs: #{job_files.join(', ')}" if job_files.any?
          end
        rescue; end

        # ApplicationController before_actions
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          app_ctrl = File.join(root, "app", "controllers", "application_controller.rb")
          if File.exist?(app_ctrl)
            source = File.read(app_ctrl)
            before_actions = source.scan(/before_action\s+:([\w!?]+)/).flatten
            lines << "Global before_actions: #{before_actions.join(', ')}" if before_actions.any?
          end
        rescue; end

        lines << ""

        # Design System (compact — character budget is tight)
        ds_lines = render_design_system(context, max_lines: 15)
        lines.concat(ds_lines) if ds_lines.any?

        # MCP tools — compact but complete (character budget is tight)
        lines << "# MCP Tools (detail:\"summary\"|\"standard\"|\"full\")"
        lines << "- rails_get_schema(table:\"name\"|detail:\"summary\"|limit:N|offset:N)"
        lines << "- rails_get_model_details(model:\"Name\"|detail:\"summary\")"
        lines << "- rails_get_routes(controller:\"name\"|detail:\"summary\"|limit:N|offset:N)"
        lines << "- rails_get_controllers(controller:\"Name\"|detail:\"summary\")"
        lines << "- rails_get_config — cache, session, middleware"
        lines << "- rails_get_test_info — framework, factories, CI"
        lines << "- rails_get_gems — categorized gems"
        lines << "- rails_get_conventions — architecture patterns"
        lines << "- rails_search_code(pattern:\"regex\"|file_type:\"rb\"|max_results:N)"
        lines << "- rails_get_edit_context(file:\"path\"|near:\"keyword\")"
        lines << "- rails_analyze_feature(feature:\"auth\") — combined context for a feature"
        lines << "- rails_get_design_system — color palette, components, page examples"
        lines << "- rails_validate(files:[\"path\"])"
        lines << "Start with detail:\"summary\", then drill into specifics."
        lines << ""
        lines << "# Rules"
        lines << "- Follow existing patterns"
        lines << "- Check schema via MCP before writing migrations"
        lines << "- Run `#{detect_test_command}` after changes"
        lines << "- After editing: use rails_validate, do NOT re-read files to verify"
        lines << "- Stimulus controllers auto-register — no manual import needed"

        lines.join("\n")
      end
    end
  end
end
