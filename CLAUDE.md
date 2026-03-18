# CLAUDE.md — rails-ai-context development guide

This is a Ruby gem that auto-introspects Rails applications and exposes their
structure to AI assistants via the Model Context Protocol (MCP).

## Architecture

- `lib/rails_ai_context.rb` — Main entry point, public API
- `lib/rails_ai_context/introspector.rb` — Orchestrates sub-introspectors
- `lib/rails_ai_context/introspectors/` — Individual introspectors (schema, models, routes, jobs, gems, conventions)
- `lib/rails_ai_context/tools/` — MCP tools using the official mcp-ruby SDK
- `lib/rails_ai_context/serializers/` — Output formatters (markdown, JSON)
- `lib/rails_ai_context/server.rb` — MCP server configuration (stdio + HTTP transports)
- `lib/rails_ai_context/engine.rb` — Rails Engine for auto-integration

## Key Design Decisions

1. **Built on official mcp-ruby SDK** — not a custom protocol implementation
2. **Zero-config** — Railtie auto-registers at boot, introspects without setup
3. **Graceful degradation** — works without DB by parsing schema.rb as text
4. **Read-only tools only** — all MCP tools are annotated as non-destructive
5. **Dual output** — static files (CLAUDE.md) + live MCP server (stdio/HTTP)

## Testing

```bash
bundle exec rspec           # Run specs
bundle exec rubocop         # Lint
```

Uses combustion gem for testing Rails engine behavior in isolation.

## Conventions

- Ruby 3.2+ features OK (pattern matching, etc.)
- Follow rubocop-rails-omakase style
- Every introspector returns a Hash, never raises (wraps errors in `{ error: msg }`)
- MCP tools return `[{ type: "text", text: "..." }]` arrays per SDK convention
- All tools prefixed with `rails_` per MCP naming best practices
