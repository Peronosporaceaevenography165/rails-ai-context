# rails-ai-context

### Your AI is guessing. This gem makes it know.

[![Gem Version](https://img.shields.io/gem/v/rails-ai-context?color=brightgreen)](https://rubygems.org/gems/rails-ai-context)
[![MCP Registry](https://img.shields.io/badge/MCP_Registry-listed-green)](https://registry.modelcontextprotocol.io)
[![CI](https://github.com/crisnahine/rails-ai-context/actions/workflows/ci.yml/badge.svg)](https://github.com/crisnahine/rails-ai-context/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Works with:** Claude Code &bull; Cursor &bull; GitHub Copilot &bull; Windsurf &bull; OpenCode

> Built by a Rails developer with 10 years of production experience. Yes, AI helped write this gem — the same way AI helps me ship features at work. I designed the architecture, made every decision, reviewed every line, and wrote 575 tests. The gem exists because I understand Rails deeply enough to know what AI agents get wrong and what context they need to get it right.

```bash
gem "rails-ai-context", group: :development
rails generate rails_ai_context:install
```

That's it. Your AI now has 25 live MCP tools that understand your entire Rails app. Zero config.

---

## What AI gets wrong without this

Right now, your AI agent:

- **Reads all 2,000 lines of schema.rb** to find one column type
- **Misses encrypted columns** — doesn't know `gemini_api_key` is encrypted
- **Shows 25 Devise methods** as if they're your code
- **Doesn't see inherited filters** — misses `authenticate_user!` from ApplicationController
- **Uses underscores in Stimulus HTML** — `data-cook_status` instead of `data-cook-status`
- **Breaks Turbo Stream wiring** — broadcasts to channels nobody subscribes to
- **Permits wrong params** — doesn't cross-check against your schema
- **Guesses your UI patterns** — invents new button styles instead of matching yours

**Every wrong guess = a wasted iteration.** You fix it, re-run, it breaks something else.

---

## What AI knows with this

One call. Full picture.

```
rails_search_code(pattern: "can_cook?", match_type: "trace")
```

```
# Trace: can_cook?

## Definition
app/models/concerns/plan_limitable.rb:8
  def can_cook?
    p = effective_plan
    return true if p.unlimited_cooks?
    (cooks_this_month || 0) < p.cooks_per_month
  end

## Calls internally
- unlimited_cooks?

## Called from (8 sites)
### app/controllers/cooks_controller.rb (Controller)
  24: unless current_user.can_cook?
### app/views/cooks/new.html.erb (View)
  7: <% unless current_user.can_cook? %>
### test/models/concerns/plan_limitable_test.rb (Test)
  24: assert @user.can_cook?
  29: assert_not @user.can_cook?
```

Definition + source code + every caller grouped by type + what it calls internally. **One tool call replaces 6 file reads.**

---

## Measured token savings

Tested on a real Rails 8 app (5 models, 19 controllers, 95 routes):

| Task | Without gem | With gem | Saved |
|------|-------------|----------|-------|
| Trace a method across the codebase | ~9,080 tokens (read 5 files) | ~198 tokens (1 MCP call) | **98%** |
| Understand a feature (schema + model + controller) | ~5,200 tokens (read 3 files) | ~1,500 tokens (2 MCP calls) | **71%** |
| Check all table columns | ~2,573 tokens (read schema.rb) | ~908 tokens (1 MCP call) | **65%** |

"Without" = AI reads files it would realistically need. "With" = MCP tools return only what's relevant.

> Savings scale with app size. A 50-model app reads more files per task — MCP calls stay the same size.

But tokens are the side effect. The real value:

- **First attempt is correct** — AI understands associations, callbacks, and constraints before writing code
- **Cross-file validation** — catches wrong columns, missing partials, broken routes in one call
- **Matches your patterns** — your button classes, your test style, your flash messages

---

## 25 Live MCP Tools

Every tool is **read-only** and returns structured, token-efficient data. Start with `detail:"summary"`, drill into specifics.

| Tool | One-liner |
|------|-----------|
| `rails_search_code` | **Trace mode**: definition + class context + source + internal calls + sibling methods + callers with route chain + test coverage. Also: `"definition"`, `"call"`, `"class"` filters, smart pagination |
| `rails_get_context` | **Composite**: schema + model + controller + routes + views in one call |
| `rails_analyze_feature` | **Full-stack**: everything about a feature — models, controllers, routes, services, jobs, views, Stimulus, tests |
| `rails_validate` | **Syntax + semantic + security** in one call. Catches wrong columns, missing partials, broken routes, Brakeman vulnerabilities |
| `rails_get_controllers` | Action source code + inherited filters + render map + side effects + private methods inline |
| `rails_get_schema` | Columns with `[indexed]`, `[unique]`, `[encrypted]`, `[default: value]` hints + model name inline |
| `rails_get_model_details` | Associations, validations, scopes with lambda body, enum backing types, macros, delegations, constants |
| `rails_get_routes` | Code-ready helpers (`cook_path(@record)`), controller filters inline, required params |
| `rails_get_view` | Templates with ivars, Turbo wiring, Stimulus refs, partial locals — pipe-separated, scannable |
| `rails_get_stimulus` | Copy-paste HTML data-attributes (dashes, not underscores) + reverse view lookup |
| `rails_get_design_system` | Canonical HTML/ERB copy-paste patterns for buttons, inputs, cards, modals |
| `rails_get_test_info` | Fixture contents with relationships + test template matching your app's patterns |
| `rails_get_conventions` | Your app's actual patterns — auth checks, flash messages, create action template, test patterns |
| `rails_get_turbo_map` | Broadcast → subscription wiring with mismatch warnings |
| `rails_get_partial_interface` | Partial locals contract — what to pass, what methods are called on each local |
| `rails_get_concern` | Public methods, signatures, which models include it |
| `rails_get_callbacks` | Callbacks in Rails execution order with source code |
| `rails_get_service_pattern` | Interface, dependencies, side effects, error handling, who calls it |
| `rails_get_job_pattern` | Queue, retries, guard clauses, Turbo broadcasts, schedules |
| `rails_get_env` | Environment variables, credentials keys (not values), external service dependencies |
| `rails_get_helper_methods` | App + framework helpers with view usage cross-references |
| `rails_get_config` | Database adapter, auth framework, assets stack, Action Cable, middleware |
| `rails_get_gems` | Notable gems with versions, categories, and config file locations |
| `rails_get_edit_context` | Method-aware code extraction with class/method context header |
| `rails_security_scan` | Brakeman static analysis — SQL injection, XSS, mass assignment |

> **[Full parameter documentation →](docs/GUIDE.md)**

---

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│  Your Rails App                                          │
│  models + schema + routes + controllers + views + jobs   │
└────────────────────────┬────────────────────────────────┘
                         │ introspects
                         ▼
┌─────────────────────────────────────────────────────────┐
│  rails-ai-context (29 introspectors)                     │
│  Parses everything. Caches results. Zero config.         │
└────────┬─────────────────────────────┬──────────────────┘
         │                             │
         ▼                             ▼
┌────────────────────┐    ┌───────────────────────────────┐
│  Static Files       │    │  Live MCP Server (25 tools)    │
│  CLAUDE.md          │    │  Real-time queries on demand   │
│  .cursor/rules/     │    │  Schema, models, routes, etc.  │
│  .github/instr...   │    │  Trace, validate, analyze      │
│  .windsurfrules     │    │  Auto-discovered via .mcp.json │
└────────────────────┘    └───────────────────────────────┘
```

The install generator asks which AI tools you use and only generates files for those.

---

## Install

```bash
# Add to Gemfile
gem "rails-ai-context", group: :development

# Install (picks your AI tools, generates context)
rails generate rails_ai_context:install

# Or generate context directly
rails ai:context
```

Both commands ask which AI tools you use (Claude, Cursor, Copilot, Windsurf, OpenCode) and only generate what you need.

MCP auto-discovery: `.mcp.json` is detected automatically by Claude Code and Cursor. No manual config.

> **[Full Guide →](docs/GUIDE.md)** — every command, parameter, and configuration option.

---

## Configuration

```ruby
# config/initializers/rails_ai_context.rb
RailsAiContext.configure do |config|
  # Which AI tools to generate context for (selected during install)
  # config.ai_tools = %i[claude cursor]

  # Presets: :full (28 introspectors, default) or :standard (13 core)
  # config.preset = :full

  # Exclude models from introspection
  # config.excluded_models += %w[AdminUser]

  # Skip specific MCP tools
  # config.skip_tools = %w[rails_security_scan]
end
```

<details>
<summary><strong>All configuration options</strong></summary>

| Option | Default | Description |
|--------|---------|-------------|
| **Presets & Introspectors** | | |
| `preset` | `:full` | Introspector preset (`:full` or `:standard`) |
| `introspectors` | 28 (full) | Array of introspector symbols |
| **Context Generation** | | |
| `context_mode` | `:compact` | `:compact` (≤150 lines) or `:full` (dump everything) |
| `claude_max_lines` | `150` | Max lines for CLAUDE.md in compact mode |
| `generate_root_files` | `true` | Generate root files (CLAUDE.md, etc.) — set `false` for split rules only |
| `ai_tools` | `nil` (all) | AI tools to generate context for: `%i[claude cursor copilot windsurf opencode]` |
| **MCP Server** | | |
| `cache_ttl` | `60` | Cache TTL in seconds |
| `max_tool_response_chars` | `200_000` | Safety cap for MCP tool responses |
| `live_reload` | `:auto` | `:auto`, `true`, or `false` — MCP live reload |
| `auto_mount` | `false` | Auto-mount HTTP MCP endpoint |
| **File Size Limits** | | |
| `max_file_size` | `5_000_000` | Per-file read limit (bytes) |
| `max_search_results` | `200` | Max search results per call |
| `max_validate_files` | `50` | Max files per validate call |
| **Extensibility** | | |
| `custom_tools` | `[]` | Additional MCP tool classes |
| `skip_tools` | `[]` | Built-in tool names to exclude |
</details>

---

## Commands

| Command | What it does |
|---------|-------------|
| `rails ai:context` | Generate context files for your AI tools |
| `rails ai:serve` | Start MCP server (stdio) |
| `rails ai:doctor` | Diagnostics + AI readiness score |
| `rails ai:watch` | Auto-regenerate on file changes |
| `rails ai:inspect` | Print introspection summary |

---

## Requirements

- Ruby >= 3.2, Rails >= 7.1
- Optional: `brakeman` for security scanning, `listen` for watch mode, `ripgrep` for fast search

---

## Contributing

```bash
git clone https://github.com/crisnahine/rails-ai-context.git
cd rails-ai-context && bundle install
bundle exec rspec       # 575 examples
bundle exec rubocop     # Lint
```

Bug reports and pull requests welcome at [github.com/crisnahine/rails-ai-context](https://github.com/crisnahine/rails-ai-context).

## Sponsorship

If rails-ai-context saves you time, consider [becoming a sponsor](https://github.com/sponsors/crisnahine).

## License

[MIT](LICENSE)
