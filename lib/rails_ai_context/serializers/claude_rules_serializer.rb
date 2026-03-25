# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .claude/rules/ files for Claude Code auto-discovery.
    # These provide quick-reference lists without bloating CLAUDE.md.
    class ClaudeRulesSerializer
      include StackOverviewHelper
      include DesignSystemHelper

      attr_reader :context

      def initialize(context)
        @context = context
      end

      # @param output_dir [String] Rails root path
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call(output_dir)
        rules_dir = File.join(output_dir, ".claude", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-context.md" => render_context_overview,
          "rails-schema.md" => render_schema_reference,
          "rails-models.md" => render_models_reference,
          "rails-ui-patterns.md" => render_ui_patterns_reference,
          "rails-mcp-tools.md" => render_mcp_tools_reference
        }

        files.each do |filename, content|
          next unless content

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

      def render_context_overview
        lines = [
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
          (conv[:architecture] || []).first(5).each { |p| lines << "- #{p}" }
        end

        lines.concat(full_preset_stack_lines)

        # ApplicationController before_actions — apply to all controllers
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          app_ctrl_file = File.join(root, "app", "controllers", "application_controller.rb")
          if File.exist?(app_ctrl_file)
            source = File.read(app_ctrl_file)
            before_actions = source.scan(/before_action\s+:([\w!?]+)/).flatten
            if before_actions.any?
              lines << "" << "**Global before_actions:** #{before_actions.join(', ')}"
            end
          end
        rescue; end

        lines << ""
        lines << "ALWAYS use MCP tools for context — do NOT read reference files directly."
        lines << "Start with `detail:\"summary\"`. Read files ONLY when you will Edit them."

        lines.join("\n")
      end

      def render_schema_reference
        schema = context[:schema]
        return nil unless schema.is_a?(Hash) && !schema[:error]
        tables = schema[:tables] || {}
        return nil if tables.empty?

        lines = [
          "# Database Tables (#{tables.size})",
          "",
          "All columns with types are listed below — no need to read db/schema.rb.",
          "For indexes, foreign keys, or constraints, use `rails_get_schema(table:\"name\")`.",
          ""
        ]

        skip_cols = %w[id created_at updated_at]
        keep_cols = %w[type deleted_at discarded_at]
        # Get enum values from models introspection if available
        models = context[:models] || {}

        tables.keys.sort.first(30).each do |name|
          data = tables[name]
          columns = data[:columns] || []
          col_count = columns.size
          pk = data[:primary_key]
          pk_display = pk.is_a?(Array) ? pk.join(", ") : (pk || "id").to_s

          # Show column names WITH types for key columns
          # Skip standard Rails FK columns (like user_id, account_id) but keep
          # external ID columns (like paymongo_checkout_id, stripe_payment_id)
          fk_columns = (data[:foreign_keys] || []).map { |f| f[:column] }.to_set
          all_table_names = tables.keys.to_set
          key_cols = columns.select do |c|
            next true if keep_cols.include?(c[:name])
            next true if c[:name].end_with?("_type")
            next false if skip_cols.include?(c[:name])
            if c[:name].end_with?("_id")
              # Skip if it's a known FK or matches a table name (conventional Rails FK)
              ref_table = c[:name].sub(/_id\z/, "").pluralize
              next false if fk_columns.include?(c[:name]) || all_table_names.include?(ref_table)
            end
            true
          end

          col_sample = key_cols.map do |c|
            col_type = c[:array] ? "#{c[:type]}[]" : c[:type].to_s
            entry = "#{c[:name]}:#{col_type}"
            if c.key?(:default) && !c[:default].nil?
              default_display = c[:default] == "" ? '""' : c[:default]
              entry += "(=#{default_display})"
            end
            entry
          end
          col_str = col_sample.any? ? " — #{col_sample.join(', ')}" : ""

          # Foreign keys
          fks = (data[:foreign_keys] || []).map { |f| "#{f[:column]}→#{f[:to_table]}" }
          fk_str = fks.any? ? " | FK: #{fks.join(', ')}" : ""

          # Key indexes (unique or composite)
          idxs = (data[:indexes] || []).select { |i| i[:unique] || Array(i[:columns]).size > 1 }
            .map { |i| i[:unique] ? "#{Array(i[:columns]).join('+')}(unique)" : Array(i[:columns]).join("+") }
          idx_str = idxs.any? ? " | Idx: #{idxs.join(', ')}" : ""

          lines << "- **#{name}** (#{col_count} cols)#{col_str}#{fk_str}#{idx_str}"

          # Include enum values if model has them
          model_name = name.classify
          model_data = models[model_name]
          if model_data.is_a?(Hash) && model_data[:enums]&.any?
            model_data[:enums].each do |attr, values|
              lines << "  #{attr}: #{values.is_a?(Hash) ? values.keys.join(', ') : Array(values).join(', ')}"
            end
          end
        end

        if tables.size > 30
          lines << "- ...#{tables.size - 30} more tables (use `rails_get_schema` MCP tool)"
        end

        lines.join("\n")
      end

      def render_models_reference
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error]
        return nil if models.empty?

        lines = [
          "# ActiveRecord Models (#{models.size})",
          "",
          "Check this file first for associations, scopes, constants, and validations.",
          "If you need more detail (callbacks, methods, business logic), use `rails_get_model_details(model:\"Name\")` or Read the file directly.",
          ""
        ]

        models.keys.sort.each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          vals = (data[:validations] || []).size
          table = data[:table_name]
          line = "- #{name}"
          line += " (table: #{table})" if table
          line += " — #{assocs} assocs, #{vals} validations"
          lines << line

          # Include app-specific concerns (filter out Rails/gem internals)
          noise = %w[GeneratedAssociationMethods GeneratedAttributeMethods Kernel PP ObjectMixin
                     GlobalID Bullet ActionText Turbo ActiveStorage JSON]
          concerns = (data[:concerns] || []).select { |c|
            !noise.any? { |n| c.include?(n) } && !c.start_with?("Devise") && !c.include?("::")
          }
          lines << "  concerns: #{concerns.join(', ')}" if concerns.any?

          # Include scopes so agents know available query methods
          scopes = data[:scopes] || []
          lines << "  scopes: #{scopes.join(', ')}" if scopes.any?

          # Instance methods — introspector already prioritizes source-defined and filters Devise
          methods = (data[:instance_methods] || []).reject { |m| m.end_with?("=") }.first(20)
          lines << "  methods: #{methods.join(', ')}" if methods.any?

          # Include constants (e.g. STATUSES, MODES) so agents know valid values
          constants = data[:constants] || []
          constants.each do |c|
            lines << "  #{c[:name]}: #{c[:values].join(', ')}"
          end

          # Include enums so agents know valid values
          enums = data[:enums] || {}
          enums.each do |attr, values|
            lines << "  #{attr}: #{values.is_a?(Hash) ? values.keys.join(', ') : Array(values).join(', ')}"
          end
        end

        lines.join("\n")
      end

      def render_ui_patterns_reference
        vt = context[:view_templates]
        return nil unless vt.is_a?(Hash) && !vt[:error]
        patterns = vt[:ui_patterns] || {}
        components = patterns[:components] || []
        return nil if components.empty?

        lines = [ "# Design System", "" ]

        # Full design system with canonical examples
        lines.concat(render_design_system_full(context))

        # Shared partials — so agents reuse them instead of recreating
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          shared_dir = File.join(root, "app", "views", "shared")
          if Dir.exist?(shared_dir)
            partials = Dir.glob(File.join(shared_dir, "_*.html.erb"))
              .map { |f| File.basename(f) }
              .sort
            if partials.any?
              lines << "" << "## Shared partials (app/views/shared/)"
              partials.each { |p| lines << "- #{p}" }
            end
          end
        rescue; end

        # Helpers — so agents use existing helpers instead of creating new ones
        begin
          root = defined?(Rails) ? Rails.root.to_s : Dir.pwd
          helper_file = File.join(root, "app", "helpers", "application_helper.rb")
          if File.exist?(helper_file)
            helper_methods = File.read(helper_file).scan(/def\s+(\w+)/).flatten
            if helper_methods.any?
              lines << "" << "## Helpers (ApplicationHelper)"
              lines << helper_methods.map { |m| "- #{m}" }.join("\n")
            end
          end
        rescue; end

        # Stimulus controllers — so agents reuse existing controllers
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

      def render_mcp_tools_reference # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        lines = [
          "# Rails MCP Tools — MANDATORY, Use Before Read/Grep",
          "",
          "CRITICAL: This project has live MCP tools. You MUST use them for gathering context.",
          "MCP tools return parsed, up-to-date, token-efficient data with line numbers.",
          "Read files ONLY when you are about to Edit them. Never read reference files directly.",
          "",
          "## Mandatory Workflow — Follow This Order",
          "",
          "### 1. Gathering context (BEFORE writing any code)",
          "- Exploring a feature area → `rails_analyze_feature(feature:\"...\")` — NOT Explore agents, NOT Grep",
          "- Understanding a model → `rails_get_model_details(model:\"...\")` — NOT reading the model file",
          "- Checking database columns → `rails_get_schema(table:\"...\")` — NOT reading db/schema.rb",
          "- Checking routes → `rails_get_routes(controller:\"...\")` — NOT reading config/routes.rb",
          "- Understanding a controller → `rails_get_controllers(controller:\"...\", action:\"...\")` — NOT reading the file",
          "- Finding code patterns → `rails_search_code(pattern:\"...\")` — NOT using Grep tool",
          "- UI patterns → `rails_get_design_system` — NOT reading view files for patterns",
          "- Full cross-layer context → `rails_get_context(model:\"...\")` — replaces multiple Read calls",
          "",
          "### 2. Reading files (ONLY files you will edit)",
          "- Read a file ONLY when you are about to Edit it (Read is required before Edit)",
          "- For everything else — schema, routes, models, tests, patterns — use MCP tools above",
          "",
          "### 3. After editing (EVERY time, no exceptions)",
          "- `rails_validate(files:[\"path/to/file.rb\", \"path/to/view.erb\"])` — one call checks all",
          "- Do NOT run `ruby -c`, `erb` checks, or `node -c` separately — use rails_validate instead",
          "- Do NOT re-read files to verify edits. Trust your Edit and validate syntax only.",
          "",
          "## Do NOT Bypass — Anti-Patterns",
          "| Instead of... | Use this MCP tool |",
          "|---------------|-------------------|",
          "| Reading db/schema.rb | `rails_get_schema(table:\"name\")` |",
          "| Reading config/routes.rb for reference | `rails_get_routes(controller:\"name\")` |",
          "| Reading model files for associations | `rails_get_model_details(model:\"Name\")` |",
          "| Grep/Explore agent for code search | `rails_search_code(pattern:\"regex\")` |",
          "| Reading test files for patterns | `rails_get_test_info(model:\"Name\")` |",
          "| Reading controller files for context | `rails_get_controllers(controller:\"Name\")` |",
          "| Reading JS files for Stimulus API | `rails_get_stimulus(controller:\"name\")` |",
          "| Multiple reads to understand a feature | `rails_analyze_feature(feature:\"keyword\")` |",
          "| ruby -c / erb / node -c after edits | `rails_validate(files:[...])` |",
          "",
          "## Reference-only files — NEVER read these, use MCP",
          "- db/schema.rb → `rails_get_schema` (column types in rails-schema.md rules for quick checks)",
          "- config/routes.rb → `rails_get_routes` (Read ONLY when adding routes)",
          "- Model files → `rails_get_model_details` (Read ONLY when editing business logic)",
          "- app/javascript/controllers/index.js → Stimulus auto-registers. Never read this.",
          "- Test files → `rails_get_test_info`",
          "",
          "## Tools (25)",
          "",
          "**rails_get_schema** — database tables, columns, indexes, foreign keys",
          "- `rails_get_schema(detail:\"summary\")` — all tables with column counts",
          "- `rails_get_schema(table:\"users\")` — full detail for one table",
          "",
          "**rails_get_model_details** — associations, validations, scopes, enums, callbacks",
          "- `rails_get_model_details(detail:\"summary\")` — list all model names",
          "- `rails_get_model_details(model:\"User\")` — full detail for one model",
          "",
          "**rails_get_routes** — HTTP verbs, paths, controller actions",
          "- `rails_get_routes(detail:\"summary\")` — route counts per controller",
          "- `rails_get_routes(controller:\"users\")` — routes for one controller",
          "",
          "**rails_get_controllers** — actions, filters, strong params, action source code",
          "- `rails_get_controllers(detail:\"summary\")` — names + action counts",
          "- `rails_get_controllers(controller:\"CooksController\", action:\"index\")` — action source code + filters",
          "",
          "**rails_get_view** — view templates, partials, Stimulus references",
          "- `rails_get_view(controller:\"cooks\")` — list all views for a controller",
          "- `rails_get_view(path:\"cooks/index.html.erb\")` — full template content",
          "",
          "**rails_get_stimulus** — Stimulus controllers with targets, values, actions",
          "- `rails_get_stimulus(detail:\"summary\")` — all controllers with counts",
          "- `rails_get_stimulus(controller:\"filter-form\")` — full detail for one controller",
          "",
          "**rails_get_test_info** — test framework, fixtures, factories, helpers",
          "- `rails_get_test_info(detail:\"full\")` — fixture names, factory names, helper setup",
          "- `rails_get_test_info(model:\"Cook\")` — full test source for a model",
          "- `rails_get_test_info(model:\"Cook\", detail:\"summary\")` — test names only (saves tokens)",
          "- `rails_get_test_info(controller:\"Cooks\")` — existing controller tests",
          "",
          "**rails_get_edit_context** — surgical edit helper with line numbers",
          "- `rails_get_edit_context(file:\"app/models/cook.rb\", near:\"scope\")` — returns code around match with line numbers",
          "",
          "**rails_validate** — syntax checker for edited files",
          "- `rails_validate(files:[\"app/models/cook.rb\"])` — checks Ruby, ERB, JS syntax in one call",
          "",
          "**rails_analyze_feature** — combined schema + models + controllers + routes for a feature area",
          "- `rails_analyze_feature(feature:\"authentication\")` — one call gets everything related to a feature",
          "",
          "**rails_get_design_system** — color palette, component patterns, canonical page examples",
          "- `rails_get_design_system(detail:\"standard\")` — colors + components + real HTML examples + design rules",
          "- `rails_get_design_system(detail:\"full\")` — + typography, responsive, dark mode, layout, spacing",
          "",
          "**rails_get_config** — cache store, session, timezone, middleware, initializers",
          "**rails_get_gems** — notable gems categorized by function",
          "**rails_get_conventions** — architecture patterns, directory structure",
          "**rails_search_code** — regex search: `rails_search_code(pattern:\"regex\", file_type:\"rb\")`",
          "",
          "**rails_security_scan** — Brakeman security analysis",
          "- `rails_security_scan` — run security scan, returns warnings by confidence",
          "",
          "**rails_get_concern** — concern methods and includers",
          "- `rails_get_concern(name:\"Searchable\")` — methods, included modules, includers",
          "",
          "**rails_get_callbacks** — model callbacks in execution order",
          "- `rails_get_callbacks(model:\"User\")` — before/after/around callbacks by type",
          "",
          "**rails_get_helper_methods** — app + framework helpers",
          "- `rails_get_helper_methods` — all helper methods across app and framework",
          "",
          "**rails_get_service_pattern** — service object patterns and interfaces",
          "- `rails_get_service_pattern` — service objects with call signatures and dependencies",
          "",
          "**rails_get_job_pattern** — background job patterns and schedules",
          "- `rails_get_job_pattern` — job classes, queues, retry policies, schedules",
          "",
          "**rails_get_env** — environment variables and credentials keys",
          "- `rails_get_env` — ENV vars referenced in code + credentials structure",
          "",
          "**rails_get_partial_interface** — partial locals contract",
          "- `rails_get_partial_interface(path:\"shared/_form\")` — required/optional locals for a partial",
          "",
          "**rails_get_turbo_map** — Turbo Streams/Frames wiring",
          "- `rails_get_turbo_map` — Turbo Frame IDs, Stream channels, broadcast sources",
          "",
          "**rails_get_context** — composite cross-layer context",
          "- `rails_get_context(model:\"User\")` — schema + model + controllers + views in one call"
        ]

        lines.join("\n")
      end
    end
  end
end
