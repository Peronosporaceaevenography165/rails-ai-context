# rails-ai-context

**Turn any Rails app into an AI-ready codebase — one gem install.**

[![Gem Version](https://badge.fury.io/rb/rails-ai-context.svg)](https://rubygems.org/gems/rails-ai-context)
[![CI](https://github.com/your-username/rails-ai-context/actions/workflows/ci.yml/badge.svg)](https://github.com/your-username/rails-ai-context/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`rails-ai-context` automatically introspects your Rails application and exposes your models, routes, schema, jobs, gems, and conventions to AI assistants through the [Model Context Protocol (MCP)](https://modelcontextprotocol.io).

**Your AI assistant instantly understands your entire Rails app. No configuration. No manual tool definitions. Just `bundle add` and go.**

---

## The Problem

You open Claude Code, Cursor, or Copilot in your Rails project and ask: *"Add a draft status to posts with a scheduled publish date."*

The AI doesn't know your schema. It doesn't know you use Devise for auth, Sidekiq for jobs, or that Post already has an `enum :status`. It generates generic code that doesn't match your app's patterns.

## The Solution

```bash
bundle add rails-ai-context
```

That's it. Now your AI assistant knows:

- 📦 **Every table, column, index, and foreign key** in your database
- 🏗️ **Every model** with its associations, validations, scopes, enums, and callbacks
- 🛤️ **Every route** with HTTP verbs, paths, and controller actions
- ⚡ **Every background job**, mailer, and Action Cable channel
- 💎 **Every notable gem** and what it means (Devise → auth, Sidekiq → jobs, Turbo → Hotwire)
- 🏛️ **Your architecture patterns**: service objects, STI, polymorphism, state machines, multi-tenancy

---

## Quick Start

### 1. Install

```bash
bundle add rails-ai-context
rails generate rails_ai_context:install
```

### 2. Generate Context Files

```bash
rails ai:context
```

This creates:
- `CLAUDE.md` — for Claude Code
- `.cursorrules` — for Cursor
- `.windsurfrules` — for Windsurf
- `.github/copilot-instructions.md` — for GitHub Copilot

**Commit these files.** Your entire team gets smarter AI assistance.

### 3. Start the MCP Server

For Claude Code / Cursor / any MCP client:

```bash
rails ai:serve
```

Or add to your Claude Code config (`~/.claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "my-rails-app": {
      "command": "bundle",
      "args": ["exec", "rails", "ai:serve"],
      "cwd": "/path/to/your/rails/app"
    }
  }
}
```

---

## MCP Tools

The gem exposes 6 tools via MCP that AI clients can call:

| Tool | Description | Annotations |
|------|-------------|-------------|
| `rails_get_schema` | Database schema: tables, columns, indexes, FKs | read-only, idempotent |
| `rails_get_routes` | All routes with HTTP verbs and controller actions | read-only, idempotent |
| `rails_get_model_details` | Model associations, validations, scopes, enums, callbacks | read-only, idempotent |
| `rails_get_gems` | Notable gems categorized by function with explanations | read-only, idempotent |
| `rails_search_code` | Ripgrep-powered code search across the codebase | read-only, idempotent |
| `rails_get_conventions` | Architecture patterns, directory structure, config files | read-only, idempotent |

All tools are **read-only** — they never modify your application or database.

---

## How It Works

```
┌─────────────────────────────────────────┐
│            Your Rails App               │
│                                         │
│  models/  routes  schema  jobs  gems    │
│     │        │       │      │     │     │
│     └────────┴───────┴──────┴─────┘     │
│                  │                       │
│         ┌───────┴────────┐              │
│         │  Introspector  │              │
│         └───────┬────────┘              │
│                 │                        │
│    ┌────────────┼────────────┐          │
│    ▼            ▼            ▼          │
│  CLAUDE.md   MCP Server   .cursorrules  │
│  (static)   (live tools)   (static)     │
└─────────────────────────────────────────┘
         │            │
         ▼            ▼
    Claude Code    Cursor / Windsurf /
    (reads file)   any MCP client
```

**Two modes:**
1. **Static files** (`rails ai:context`) — generates markdown files that AI tools read as project context. Zero runtime cost. Works everywhere.
2. **MCP server** (`rails ai:serve`) — live introspection tools that AI clients call on-demand. Richer, always up-to-date.

---

## Configuration

```ruby
# config/initializers/rails_ai_context.rb
RailsAiContext.configure do |config|
  # Exclude internal models from introspection
  config.excluded_models += %w[AdminUser InternalAuditLog]

  # Exclude paths from code search
  config.excluded_paths += %w[vendor/bundle]

  # Auto-mount HTTP MCP endpoint (for remote AI clients)
  config.auto_mount = true
  config.http_path  = "/mcp"
  config.http_port  = 6029
end
```

---

## Rake Tasks

| Command | Description |
|---------|-------------|
| `rails ai:context` | Generate all context files (CLAUDE.md, .cursorrules, etc.) |
| `rails ai:context_for[claude]` | Generate for a specific format |
| `rails ai:serve` | Start MCP server (stdio, for Claude Code) |
| `rails ai:serve_http` | Start MCP server (HTTP, for remote clients) |
| `rails ai:inspect` | Print introspection summary to stdout |

---

## Works Without a Database

The gem gracefully degrades when no database is connected — it parses `db/schema.rb` as text. This means it works in:

- CI environments
- Claude Code sessions (no DB running)
- Docker build stages
- Any environment where you have the source code but not a running database

---

## Requirements

- Ruby >= 3.2
- Rails >= 7.1
- [mcp-ruby](https://github.com/modelcontextprotocol/ruby-sdk) (official MCP SDK, installed automatically)

---

## vs. Other Ruby MCP Projects

| Project | What it does | How rails-ai-context differs |
|---------|-------------|------------------------------|
| [Official Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) | Low-level MCP protocol library | We **use** this as our foundation |
| [fast-mcp](https://github.com/yjacquin/fast-mcp) | Generic Ruby MCP framework | We're a **product**, not a framework — zero-config Rails introspection |
| [rails-mcp-server](https://github.com/maquina-app/rails-mcp-server) | Rails MCP server with manual config | We auto-discover everything, no `projects.yml` needed |
| [mcp_on_ruby](https://github.com/rubyonai/mcp_on_ruby) | MCP server with manual tool definitions | We auto-generate tools from your app's structure |

**rails-ai-context is not another MCP SDK.** It's a product that gives your Rails app AI superpowers with one `bundle add`.

---

## Development

```bash
git clone https://github.com/your-username/rails-ai-context.git
cd rails-ai-context
bundle install
bundle exec rspec
```

## Contributing

Bug reports and pull requests welcome at https://github.com/your-username/rails-ai-context.

## License

[MIT License](LICENSE)
