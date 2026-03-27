# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Shared helper for rendering the tool reference section in context files.
    # Reads config.tool_mode to generate MCP syntax, CLI syntax, or both.
    module ToolGuideHelper
      # Returns the tool invocation example for a given tool call.
      # MCP: rails_analyze_feature(feature:"cook")
      # CLI: rails 'ai:tool[analyze_feature]' feature=cook
      def tool_call(mcp_call, cli_call)
        case tool_mode
        when :cli
          "→ `#{cli_call}`"
        when :mcp
          "→ MCP: `#{mcp_call}`\n→ CLI: `#{cli_call}`"
        else
          "→ `#{mcp_call}`"
        end
      end

      def tool_mode
        RailsAiContext.configuration.tool_mode
      end

      def tools_header
        "## Tools (29) — MANDATORY, Use Before Read"
      end

      def tools_intro
        case tool_mode
        when :cli
          [
            "This project has 29 introspection tools. **MANDATORY — use these instead of reading files.**",
            "They return only relevant, structured data and save tokens. Read files ONLY when you are about to Edit them.",
            ""
          ]
        else
          [
            "This project has 29 MCP tools via `rails ai:serve` (configured in `.mcp.json`).",
            "**MANDATORY — use these instead of reading files.** They return structured data and save tokens.",
            "Read files ONLY when you are about to Edit them.",
            "If MCP tools are not connected, use CLI fallback: `#{cli_cmd("TOOL_NAME", "param=value")}`",
            ""
          ]
        end
      end

      def tools_task_section # rubocop:disable Metrics/MethodLength
        [
          "### What Are You Trying to Do?",
          "",
          "**Understand a feature or area:**",
          tool_call("rails_analyze_feature(feature:\"cook\")", cli_cmd("analyze_feature", "feature=cook")),
          tool_call("rails_get_context(model:\"Cook\")", cli_cmd("context", "model=Cook")),
          "",
          "**Understand a method (who calls it, what it calls):**",
          tool_call("rails_search_code(pattern:\"can_cook?\", match_type:\"trace\")", cli_cmd("search_code", "pattern=\"can_cook?\" match_type=trace")),
          "",
          "**Add a field or modify a model:**",
          tool_call("rails_get_schema(table:\"cooks\")", cli_cmd("schema", "table=cooks")),
          tool_call("rails_get_model_details(model:\"Cook\")", cli_cmd("model_details", "model=Cook")),
          tool_call("rails_migration_advisor(action:\"add_column\", table:\"cooks\", column:\"rating\", type:\"integer\")", cli_cmd("migration_advisor", "action=add_column table=cooks column=rating type=integer")),
          "",
          "**Fix a controller bug:**",
          tool_call("rails_get_controllers(controller:\"CooksController\", action:\"create\")", cli_cmd("controllers", "controller=CooksController action=create")),
          "",
          "**Build or modify a view:**",
          tool_call("rails_get_design_system(detail:\"standard\")", cli_cmd("design_system", "detail=standard")),
          tool_call("rails_get_view(controller:\"cooks\")", cli_cmd("view", "controller=cooks")),
          tool_call("rails_get_partial_interface(partial:\"shared/status_badge\")", cli_cmd("partial_interface", "partial=shared/status_badge")),
          tool_call("rails_get_component_catalog(component:\"Alert\")", cli_cmd("component_catalog", "component=Alert")),
          "",
          "**Write tests:**",
          tool_call("rails_get_test_info(detail:\"standard\")", cli_cmd("test_info", "detail=standard")),
          tool_call("rails_get_test_info(model:\"Cook\")", cli_cmd("test_info", "model=Cook")),
          "",
          "**Find code:**",
          tool_call("rails_search_code(pattern:\"has_many\")", cli_cmd("search_code", "pattern=\"has_many\"")),
          tool_call("rails_search_code(pattern:\"create\", match_type:\"definition\")", cli_cmd("search_code", "pattern=create match_type=definition")),
          "",
          "**Check performance:**",
          tool_call("rails_performance_check(model:\"Cook\")", cli_cmd("performance_check", "model=Cook")),
          "",
          "**Understand dependencies:**",
          tool_call("rails_dependency_graph(model:\"Cook\", format:\"mermaid\")", cli_cmd("dependency_graph", "model=Cook format=mermaid")),
          "",
          "**After editing (EVERY time):**",
          tool_call("rails_validate(files:[\"app/models/cook.rb\"], level:\"rails\")", cli_cmd("validate", "files=app/models/cook.rb level=rails")),
          ""
        ]
      end

      def tools_rules_section
        case tool_mode
        when :cli
          [
            "### Rules",
            "",
            "1. NEVER read db/schema.rb, config/routes.rb, model files, or test files for reference — use the CLI tools above",
            "2. NEVER use Grep or search agents for code search — use `#{cli_cmd("search_code")}`",
            "3. NEVER run `ruby -c`, `erb`, or `node -c` — use `#{cli_cmd("validate")}`",
            "4. Read files ONLY when you are about to Edit them",
            "5. Start with `detail=summary` to orient, then drill into specifics",
            ""
          ]
        else
          [
            "### Rules",
            "",
            "1. NEVER read db/schema.rb, config/routes.rb, model files, or test files for reference — use the MCP tools above",
            "2. NEVER use Grep or search agents for code search — use `rails_search_code`",
            "3. NEVER run `ruby -c`, `erb`, or `node -c` — use `rails_validate`",
            "4. Read files ONLY when you are about to Edit them",
            "5. Start with `detail:\"summary\"` to orient, then drill into specifics",
            "6. If MCP tools are not connected, use CLI: `#{cli_cmd("TOOL_NAME", "param=value")}`",
            ""
          ]
        end
      end

      def tools_table # rubocop:disable Metrics/MethodLength
        lines = [ "### All 29 Tools", "" ]

        if tool_mode == :cli
          lines.concat(tools_table_cli)
        else
          lines.concat(tools_table_mcp_and_cli)
        end

        lines
      end

      def tools_table_mcp_and_cli # rubocop:disable Metrics/MethodLength
        [
          "| MCP | CLI | What it does |",
          "|-----|-----|-------------|",
          "| `rails_analyze_feature(feature:\"X\")` | `#{cli_cmd("analyze_feature", "feature=X")}` | Full-stack: models + controllers + routes + services + jobs + views + tests |",
          "| `rails_get_context(model:\"X\")` | `#{cli_cmd("context", "model=X")}` | Composite: schema + model + controller + routes + views in one call |",
          "| `rails_search_code(pattern:\"X\", match_type:\"trace\")` | `#{cli_cmd("search_code", "pattern=X match_type=trace")}` | Trace: definition + source + siblings + callers + test coverage |",
          "| `rails_get_controllers(controller:\"X\", action:\"Y\")` | `#{cli_cmd("controllers", "controller=X action=Y")}` | Action source + inherited filters + render map + private methods |",
          "| `rails_validate(files:[...], level:\"rails\")` | `#{cli_cmd("validate", "files=a.rb,b.rb level=rails")}` | Syntax + semantic validation + Brakeman security |",
          "| `rails_get_schema(table:\"X\")` | `#{cli_cmd("schema", "table=X")}` | Columns with [indexed]/[unique]/[encrypted]/[default] hints |",
          "| `rails_get_model_details(model:\"X\")` | `#{cli_cmd("model_details", "model=X")}` | Associations, validations, scopes, enums, macros, delegations |",
          "| `rails_get_routes(controller:\"X\")` | `#{cli_cmd("routes", "controller=X")}` | Routes with code-ready helpers and controller filters inline |",
          "| `rails_get_view(controller:\"X\")` | `#{cli_cmd("view", "controller=X")}` | Templates with ivars, Turbo wiring, Stimulus refs, partial locals |",
          "| `rails_get_design_system` | `#{cli_cmd("design_system")}` | Canonical HTML/ERB copy-paste patterns for buttons, inputs, cards |",
          "| `rails_get_stimulus(controller:\"X\")` | `#{cli_cmd("stimulus", "controller=X")}` | Targets, values, actions + HTML data-attributes + view lookup |",
          "| `rails_get_test_info(model:\"X\")` | `#{cli_cmd("test_info", "model=X")}` | Tests + fixture contents + test template |",
          "| `rails_get_concern(name:\"X\", detail:\"full\")` | `#{cli_cmd("concern", "name=X detail=full")}` | Concern methods with source + which models include it |",
          "| `rails_get_callbacks(model:\"X\")` | `#{cli_cmd("callbacks", "model=X")}` | Callbacks in Rails execution order with source |",
          "| `rails_get_edit_context(file:\"X\", near:\"Y\")` | `#{cli_cmd("edit_context", "file=X near=Y")}` | Code around a match with class/method context |",
          "| `rails_search_code(pattern:\"X\")` | `#{cli_cmd("search_code", "pattern=X")}` | Regex search + `exclude_tests` + `group_by_file` + pagination |",
          "| `rails_get_service_pattern` | `#{cli_cmd("service_pattern")}` | Service objects: interface, dependencies, side effects, callers |",
          "| `rails_get_job_pattern` | `#{cli_cmd("job_pattern")}` | Jobs: queue, retries, guard clauses, broadcasts, schedules |",
          "| `rails_get_env` | `#{cli_cmd("env")}` | Environment variables + credentials keys (not values) |",
          "| `rails_get_partial_interface(partial:\"X\")` | `#{cli_cmd("partial_interface", "partial=X")}` | Partial locals contract: what to pass + usage examples |",
          "| `rails_get_turbo_map` | `#{cli_cmd("turbo_map")}` | Turbo Stream/Frame wiring + mismatch warnings |",
          "| `rails_get_helper_methods` | `#{cli_cmd("helper_methods")}` | App + framework helpers with view cross-references |",
          "| `rails_get_config` | `#{cli_cmd("config")}` | Database adapter, auth, assets, cache, queue, Action Cable |",
          "| `rails_get_gems` | `#{cli_cmd("gems")}` | Notable gems with versions, categories, config file locations |",
          "| `rails_get_conventions` | `#{cli_cmd("conventions")}` | App patterns: auth checks, flash messages, test patterns |",
          "| `rails_security_scan` | `#{cli_cmd("security_scan")}` | Brakeman static analysis: SQL injection, XSS, mass assignment |",
          "| `rails_get_component_catalog(component:\"X\")` | `#{cli_cmd("component_catalog", "component=X")}` | ViewComponent/Phlex: props, slots, previews, usage |",
          "| `rails_performance_check(model:\"X\")` | `#{cli_cmd("performance_check", "model=X")}` | N+1 risks, missing indexes, Model.all anti-patterns |",
          "| `rails_dependency_graph(model:\"X\")` | `#{cli_cmd("dependency_graph", "model=X")}` | Model association graph as Mermaid diagram |",
          "| `rails_migration_advisor(action:\"X\", table:\"Y\")` | `#{cli_cmd("migration_advisor", "action=X table=Y")}` | Generate migration code, flag irreversible ops |"
        ]
      end

      def tools_table_cli # rubocop:disable Metrics/MethodLength
        [
          "| CLI | What it does |",
          "|-----|-------------|",
          "| `#{cli_cmd("analyze_feature", "feature=X")}` | Full-stack: models + controllers + routes + services + jobs + views + tests |",
          "| `#{cli_cmd("context", "model=X")}` | Composite: schema + model + controller + routes + views in one call |",
          "| `#{cli_cmd("search_code", "pattern=X match_type=trace")}` | Trace: definition + source + siblings + callers + test coverage |",
          "| `#{cli_cmd("controllers", "controller=X action=Y")}` | Action source + inherited filters + render map + private methods |",
          "| `#{cli_cmd("validate", "files=a.rb,b.rb level=rails")}` | Syntax + semantic validation + Brakeman security |",
          "| `#{cli_cmd("schema", "table=X")}` | Columns with [indexed]/[unique]/[encrypted]/[default] hints |",
          "| `#{cli_cmd("model_details", "model=X")}` | Associations, validations, scopes, enums, macros, delegations |",
          "| `#{cli_cmd("routes", "controller=X")}` | Routes with code-ready helpers and controller filters inline |",
          "| `#{cli_cmd("view", "controller=X")}` | Templates with ivars, Turbo wiring, Stimulus refs, partial locals |",
          "| `#{cli_cmd("design_system")}` | Canonical HTML/ERB copy-paste patterns for buttons, inputs, cards |",
          "| `#{cli_cmd("stimulus", "controller=X")}` | Targets, values, actions + HTML data-attributes + view lookup |",
          "| `#{cli_cmd("test_info", "model=X")}` | Tests + fixture contents + test template |",
          "| `#{cli_cmd("concern", "name=X detail=full")}` | Concern methods with source + which models include it |",
          "| `#{cli_cmd("callbacks", "model=X")}` | Callbacks in Rails execution order with source |",
          "| `#{cli_cmd("edit_context", "file=X near=Y")}` | Code around a match with class/method context |",
          "| `#{cli_cmd("search_code", "pattern=X")}` | Regex search + `exclude_tests` + `group_by_file` + pagination |",
          "| `#{cli_cmd("service_pattern")}` | Service objects: interface, dependencies, side effects, callers |",
          "| `#{cli_cmd("job_pattern")}` | Jobs: queue, retries, guard clauses, broadcasts, schedules |",
          "| `#{cli_cmd("env")}` | Environment variables + credentials keys (not values) |",
          "| `#{cli_cmd("partial_interface", "partial=X")}` | Partial locals contract: what to pass + usage examples |",
          "| `#{cli_cmd("turbo_map")}` | Turbo Stream/Frame wiring + mismatch warnings |",
          "| `#{cli_cmd("helper_methods")}` | App + framework helpers with view cross-references |",
          "| `#{cli_cmd("config")}` | Database adapter, auth, assets, cache, queue, Action Cable |",
          "| `#{cli_cmd("gems")}` | Notable gems with versions, categories, config file locations |",
          "| `#{cli_cmd("conventions")}` | App patterns: auth checks, flash messages, test patterns |",
          "| `#{cli_cmd("security_scan")}` | Brakeman static analysis: SQL injection, XSS, mass assignment |",
          "| `#{cli_cmd("component_catalog", "component=X")}` | ViewComponent/Phlex: props, slots, previews, usage |",
          "| `#{cli_cmd("performance_check", "model=X")}` | N+1 risks, missing indexes, Model.all anti-patterns |",
          "| `#{cli_cmd("dependency_graph", "model=X")}` | Model association graph as Mermaid diagram |",
          "| `#{cli_cmd("migration_advisor", "action=X table=Y")}` | Generate migration code, flag irreversible ops |"
        ]
      end

      # Full tool guide section — used by all serializers.
      def render_tools_guide
        lines = []
        lines << tools_header
        lines << ""
        lines.concat(tools_intro)
        lines.concat(tools_task_section)
        lines.concat(tools_rules_section)
        lines.concat(tools_table)
        lines
      end

      private

      # Generate zsh-safe CLI command: rails 'ai:tool[name]' params
      def cli_cmd(tool_name, params = nil)
        cmd = "rails 'ai:tool[#{tool_name}]'"
        cmd += " #{params}" if params
        cmd
      end
    end
  end
end
