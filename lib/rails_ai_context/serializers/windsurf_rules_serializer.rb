# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .windsurf/rules/*.md files in the new Windsurf rules format.
    # Each file is hard-capped at 5,800 characters (within Windsurf's 6K limit).
    class WindsurfRulesSerializer
      include DesignSystemHelper

      MAX_CHARS_PER_FILE = 5_800

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call(output_dir)
        rules_dir = File.join(output_dir, ".windsurf", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-context.md" => render_context_rule,
          "rails-ui-patterns.md" => render_ui_patterns_rule,
          "rails-mcp-tools.md" => render_mcp_tools_rule
        }

        files.each do |filename, content|
          next unless content
          # Enforce Windsurf's 6K limit
          content = content[0...MAX_CHARS_PER_FILE] if content.length > MAX_CHARS_PER_FILE

          filepath = File.join(rules_dir, filename)
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

      def render_context_rule
        # Reuse WindsurfSerializer content
        WindsurfSerializer.new(context).call
      end

      def render_ui_patterns_rule
        vt = context[:view_templates]
        return nil unless vt.is_a?(Hash) && !vt[:error]
        components = vt.dig(:ui_patterns, :components) || []
        return nil if components.empty?

        # Compact design system for Windsurf's character budget
        lines = render_design_system(context, max_lines: 25)
        return nil if lines.empty?

        lines.join("\n")
      end

      def render_mcp_tools_rule # rubocop:disable Metrics/MethodLength
        lines = [
          "# Rails MCP Tools (25) — MANDATORY, Use Before Read",
          "",
          "CRITICAL: This project has live MCP tools. Use them for ALL context gathering.",
          "Read files ONLY when you are about to edit them.",
          "",
          "Mandatory Workflow:",
          "1. Gathering context → use MCP tools (NOT file reads)",
          "2. Reading files → ONLY files you will edit",
          "3. After editing → rails_validate(files:[...]) every time",
          "",
          "Do NOT Bypass:",
          "- Reading db/schema.rb → rails_get_schema(table:\"name\")",
          "- Reading config/routes.rb → rails_get_routes(controller:\"name\")",
          "- Reading model files → rails_get_model_details(model:\"Name\")",
          "- Grep for code → rails_search_code(pattern:\"regex\")",
          "- Reading test files → rails_get_test_info(model:\"Name\")",
          "- Reading controller → rails_get_controllers(controller:\"Name\", action:\"x\")",
          "- Reading JS for Stimulus → rails_get_stimulus(controller:\"name\")",
          "- Multiple reads for feature → rails_analyze_feature(feature:\"keyword\")",
          "- ruby -c / erb / node -c → rails_validate(files:[...])",
          "",
          "All 25 Tools:",
          "- rails_get_schema | rails_get_model_details | rails_get_routes | rails_get_controllers",
          "- rails_get_view | rails_get_stimulus | rails_get_test_info | rails_analyze_feature",
          "- rails_get_design_system | rails_get_edit_context | rails_validate | rails_search_code",
          "- rails_get_config | rails_get_gems | rails_get_conventions | rails_security_scan",
          "- rails_get_concern | rails_get_callbacks | rails_get_helper_methods | rails_get_service_pattern",
          "- rails_get_job_pattern | rails_get_env | rails_get_partial_interface | rails_get_turbo_map",
          "- rails_get_context(model:\"X\") — composite cross-layer context in one call",
          "",
          "Power Features:",
          "- rails_search_code(pattern:\"method\", match_type:\"trace\") — trace: definition + source + siblings + callers + tests",
          "- rails_get_concern(name:\"X\", detail:\"full\") — concern methods with source code",
          "- rails_analyze_feature — full-stack with inherited filters, route helpers, test gaps",
          "- rails_get_schema — columns, indexes, defaults, encrypted hints, orphaned table warnings"
        ]

        lines.join("\n")
      end
    end
  end
end
