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

      def render_mcp_tools_rule # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        lines = [
          "# Rails MCP Tools — MANDATORY, Use Before Read/Grep",
          "",
          "This project has 25 live MCP tools. You MUST use them instead of reading files.",
          "Read files ONLY when you are about to Edit them.",
          "",
          "What Are You Trying to Do?",
          "",
          "Understand a feature or area:",
          "  rails_analyze_feature(feature:\"cook\") — models + controllers + routes + services + jobs + views + tests in one call",
          "  rails_get_context(model:\"Cook\") — schema + model + controller + views assembled together",
          "",
          "Understand a method (who calls it, what it calls):",
          "  rails_search_code(pattern:\"can_cook?\", match_type:\"trace\") — definition + source + siblings + all callers + test coverage",
          "",
          "Add a field or modify a model:",
          "  rails_get_schema(table:\"cooks\") — columns, types, indexes, defaults, encrypted hints",
          "  rails_get_model_details(model:\"Cook\") — associations, validations, scopes, enums, callbacks, macros",
          "",
          "Fix a controller bug:",
          "  rails_get_controllers(controller:\"CooksController\", action:\"create\") — source + inherited filters + render map + side effects + private methods",
          "",
          "Build or modify a view:",
          "  rails_get_design_system(detail:\"standard\") — canonical HTML/ERB patterns to copy",
          "  rails_get_view(controller:\"cooks\") — templates with ivars, Turbo wiring, Stimulus refs",
          "  rails_get_partial_interface(partial:\"shared/status_badge\") — what locals to pass",
          "",
          "Write tests:",
          "  rails_get_test_info(detail:\"standard\") — framework + fixtures + test template to copy",
          "  rails_get_test_info(model:\"Cook\") — existing tests for a model",
          "",
          "Find code:",
          "  rails_search_code(pattern:\"has_many\") — regex search with 2 lines of context",
          "  rails_search_code(pattern:\"create\", match_type:\"definition\") — only def lines",
          "  rails_search_code(pattern:\"can_cook\", match_type:\"call\") — only call sites",
          "",
          "After editing (EVERY time):",
          "  rails_validate(files:[\"app/models/cook.rb\", \"app/views/cooks/new.html.erb\"], level:\"rails\") — syntax + semantics + security",
          "",
          "Rules:",
          "1. NEVER read db/schema.rb, config/routes.rb, model files, or test files for reference — use the MCP tools above",
          "2. NEVER use Grep for code search — use rails_search_code",
          "3. NEVER run ruby -c, erb, or node -c — use rails_validate",
          "4. Read files ONLY when you are about to Edit them",
          "5. Start with detail:\"summary\" to orient, then drill into specifics",
          "",
          "All 25 Tools:",
          "rails_analyze_feature(feature:\"X\") — Full-stack: models + controllers + routes + services + jobs + views + tests + gaps",
          "rails_get_context(model:\"X\") — Composite: schema + model + controller + routes + views in one call",
          "rails_search_code(pattern:\"X\", match_type:\"trace\") — Trace: definition + source + siblings + callers + test coverage",
          "rails_get_controllers(controller:\"X\", action:\"Y\") — Action source + inherited filters + render map + side effects",
          "rails_validate(files:[...], level:\"rails\") — Syntax + semantic validation + Brakeman security",
          "rails_get_schema(table:\"X\") — Columns with indexed/unique/encrypted/default + orphaned table warnings",
          "rails_get_model_details(model:\"X\") — Associations, validations, scopes, enums, macros, delegations",
          "rails_get_routes(controller:\"X\") — Routes with code-ready helpers and controller filters inline",
          "rails_get_view(controller:\"X\") — Templates with ivars, Turbo Frame/Stream IDs, Stimulus refs, partial locals",
          "rails_get_design_system — Canonical HTML/ERB copy-paste patterns for buttons, inputs, cards, modals",
          "rails_get_stimulus(controller:\"X\") — Targets, values, actions + copy-paste HTML data-attributes",
          "rails_get_test_info(model:\"X\") — Existing tests + fixture contents + test template",
          "rails_get_concern(name:\"X\", detail:\"full\") — Concern methods with full source code + includers",
          "rails_get_callbacks(model:\"X\") — Callbacks in Rails execution order with source",
          "rails_get_edit_context(file:\"X\", near:\"Y\") — Code around a match with class/method context + line numbers",
          "rails_search_code(pattern:\"X\") — Regex search with smart limiting + exclude_tests + group_by_file",
          "rails_get_service_pattern — Service objects: interface, dependencies, side effects, callers",
          "rails_get_job_pattern — Jobs: queue, retries, guard clauses, broadcasts, schedules",
          "rails_get_env — Environment variables + credentials keys (not values) + external services",
          "rails_get_partial_interface(partial:\"X\") — Partial locals contract: what to pass + usage examples",
          "rails_get_turbo_map — Turbo Stream/Frame wiring: broadcasts to subscriptions + mismatch warnings",
          "rails_get_helper_methods — App + framework helper methods with view cross-references",
          "rails_get_config — Database adapter, auth framework, assets stack, cache, queue, Action Cable",
          "rails_get_gems — Notable gems with versions, categories, config file locations",
          "rails_get_conventions — App patterns: auth checks, flash messages, create action template, test patterns",
          "rails_security_scan — Brakeman static analysis: SQL injection, XSS, mass assignment"
        ]

        lines.join("\n")
      end
    end
  end
end
