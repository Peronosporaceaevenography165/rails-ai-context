# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .github/instructions/*.instructions.md files with applyTo frontmatter
    # for GitHub Copilot path-specific instructions.
    class CopilotInstructionsSerializer
      include StackOverviewHelper
      include DesignSystemHelper

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call(output_dir)
        dir = File.join(output_dir, ".github", "instructions")
        FileUtils.mkdir_p(dir)

        written = []
        skipped = []

        files = {
          "rails-context.instructions.md" => render_context_instructions,
          "rails-models.instructions.md" => render_models_instructions,
          "rails-controllers.instructions.md" => render_controllers_instructions,
          "rails-ui-patterns.instructions.md" => render_ui_patterns_instructions,
          "rails-mcp-tools.instructions.md" => render_mcp_tools_instructions
        }

        files.each do |filename, content|
          next unless content
          filepath = File.join(dir, filename)
          if File.exist?(filepath) && File.read(filepath) == content
            skipped << filepath
          else
            File.write(filepath, content)
            written << filepath
          end
        end

        { written: written, skipped: skipped }
      end

      private

      def render_context_instructions
        lines = [
          "---",
          "applyTo: \"**/*\"",
          "---",
          "",
          "# #{context[:app_name] || 'Rails App'} — Overview",
          "",
          "Rails #{context[:rails_version]} | Ruby #{context[:ruby_version]}",
          ""
        ]

        schema = context[:schema]
        if schema.is_a?(Hash) && !schema[:error]
          lines << "- Database: #{schema[:adapter]} — #{schema[:total_tables]} tables"
        end

        models = context[:models]
        lines << "- Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        lines << "- Routes: #{routes[:total_routes]}" if routes.is_a?(Hash) && !routes[:error]

        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = gems[:notable_gems] || []
          notable.group_by { |g| g[:category]&.to_s || "other" }.first(6).each do |cat, gem_list|
            lines << "- #{cat}: #{gem_list.map { |g| g[:name] }.join(', ')}"
          end
        end

        conv = context[:conventions]
        if conv.is_a?(Hash) && !conv[:error]
          arch_labels = RailsAiContext::Tools::GetConventions::ARCH_LABELS rescue {}
          (conv[:architecture] || []).first(5).each { |p| lines << "- #{arch_labels[p] || p}" }
        end

        lines.concat(full_preset_stack_lines)

        # List service objects
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          services_dir = File.join(root, "app", "services")
          if Dir.exist?(services_dir)
            service_files = Dir.glob(File.join(services_dir, "*.rb"))
              .map { |f| File.basename(f, ".rb").camelize }
              .reject { |s| s == "ApplicationService" }
            lines << "- Services: #{service_files.join(', ')}" if service_files.any?
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
            lines << "- Jobs: #{job_files.join(', ')}" if job_files.any?
          end
        rescue; end

        # ApplicationController before_actions
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          app_ctrl = File.join(root, "app", "controllers", "application_controller.rb")
          if File.exist?(app_ctrl)
            source = File.read(app_ctrl)
            before_actions = source.scan(/before_action\s+:([\w!?]+)/).flatten
            lines << "" << "**Global before_actions:** #{before_actions.join(', ')}" if before_actions.any?
          end
        rescue; end

        lines << ""
        lines << "Use MCP tools for detailed data. Start with `detail:\"summary\"`."

        lines.join("\n")
      end

      def render_models_instructions
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error] && models.any?

        lines = [
          "---",
          "applyTo: \"app/models/**/*.rb\"",
          "---",
          "",
          "# ActiveRecord Models (#{models.size})",
          "",
          "Check here first for scopes, constants, associations. Read model files for business logic/methods.",
          ""
        ]

        models.keys.sort.first(30).each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          lines << "- #{name} (#{assocs} associations)"
          scopes = (data[:scopes] || [])
          constants = (data[:constants] || [])
          if scopes.any? || constants.any?
            extras = []
            extras << "scopes: #{scopes.join(', ')}" if scopes.any?
            constants.each { |c| extras << "#{c[:name]}: #{c[:values].join(', ')}" }
            lines << "  #{extras.join(' | ')}"
          end
        end

        lines << "- ...#{models.size - 30} more" if models.size > 30
        lines.join("\n")
      end

      def render_controllers_instructions
        data = context[:controllers]
        return nil unless data.is_a?(Hash) && !data[:error]
        controllers = data[:controllers] || {}
        return nil if controllers.empty?

        lines = [
          "---",
          "applyTo: \"app/controllers/**/*.rb\"",
          "---",
          "",
          "# Controllers (#{controllers.size})",
          "",
          "Use `rails_get_controllers` MCP tool for full details.",
          ""
        ]

        controllers.keys.sort.first(25).each do |name|
          info = controllers[name]
          actions = info[:actions]&.size || 0
          lines << "- #{name} (#{actions} actions)"
        end

        lines.join("\n")
      end

      def render_ui_patterns_instructions
        vt = context[:view_templates]
        return nil unless vt.is_a?(Hash) && !vt[:error]
        components = vt.dig(:ui_patterns, :components) || []
        return nil if components.empty?

        lines = [
          "---",
          "applyTo: \"app/views/**/*.erb\"",
          "---",
          ""
        ]

        lines.concat(render_design_system_full(context))

        # Stimulus controllers
        stim = context[:stimulus]
        if stim.is_a?(Hash) && !stim[:error]
          controllers = stim[:controllers] || []
          if controllers.any?
            names = controllers.map { |c| c[:name] || c[:file]&.gsub("_controller.js", "") }.compact.sort
            lines << "" << "## Stimulus controllers"
            lines << names.join(", ")
          end
        end

        lines.join("\n")
      end

      def render_mcp_tools_instructions # rubocop:disable Metrics/MethodLength
        lines = [
          "---",
          "applyTo: \"**/*\"",
          "---",
          "",
          "# Rails MCP Tools (25) — MANDATORY, Use Before Read",
          "",
          "CRITICAL: This project has live MCP tools. You MUST use them for gathering context.",
          "Read files ONLY when you are about to edit them. Never read reference files directly.",
          "Start with `detail:\"summary\"`, then drill into specifics.",
          "",
          "## Mandatory Workflow",
          "1. Gathering context → use MCP tools (NOT file reads, NOT grep)",
          "2. Reading files → ONLY files you will edit",
          "3. After editing → `rails_validate(files:[...])` every time, no exceptions",
          "",
          "## Do NOT Bypass",
          "| Instead of... | Use this MCP tool |",
          "|---------------|-------------------|",
          "| Reading db/schema.rb | `rails_get_schema(table:\"name\")` |",
          "| Reading config/routes.rb | `rails_get_routes(controller:\"name\")` |",
          "| Reading model files for context | `rails_get_model_details(model:\"Name\")` |",
          "| Grep for code patterns | `rails_search_code(pattern:\"regex\")` |",
          "| Reading test files | `rails_get_test_info(model:\"Name\")` |",
          "| Reading controller for context | `rails_get_controllers(controller:\"Name\", action:\"x\")` |",
          "| Reading JS for Stimulus API | `rails_get_stimulus(controller:\"name\")` |",
          "| Multiple reads for a feature | `rails_analyze_feature(feature:\"keyword\")` |",
          "| ruby -c / erb / node -c | `rails_validate(files:[...])` |",
          "",
          "## All 25 Tools",
          "- `rails_get_schema` | `rails_get_model_details` | `rails_get_routes` | `rails_get_controllers`",
          "- `rails_get_view` | `rails_get_stimulus` | `rails_get_test_info` | `rails_analyze_feature`",
          "- `rails_get_design_system` | `rails_get_edit_context` | `rails_validate` | `rails_search_code`",
          "- `rails_get_config` | `rails_get_gems` | `rails_get_conventions` | `rails_security_scan`",
          "- `rails_get_concern` | `rails_get_callbacks` | `rails_get_helper_methods` | `rails_get_service_pattern`",
          "- `rails_get_job_pattern` | `rails_get_env` | `rails_get_partial_interface` | `rails_get_turbo_map`",
          "- `rails_get_context(model:\"X\")` — composite cross-layer context in one call",
          "",
          "## Power Features",
          "- `rails_search_code(pattern:\"method\", match_type:\"trace\")` — trace: definition + source + siblings + callers + tests",
          "- `rails_get_concern(name:\"X\", detail:\"full\")` — concern methods with source code",
          "- `rails_analyze_feature` — full-stack with inherited filters, route helpers, test gaps",
          "- `rails_get_schema` — columns, indexes, defaults, encrypted hints, orphaned table warnings"
        ]

        lines.join("\n")
      end
    end
  end
end
