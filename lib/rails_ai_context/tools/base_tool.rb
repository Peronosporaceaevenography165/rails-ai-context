# frozen_string_literal: true

require "mcp"

module RailsAiContext
  module Tools
    # Base class for all MCP tools exposed by rails-ai-context.
    # Inherits from the official MCP::Tool to get schema validation,
    # annotations, and protocol compliance for free.
    class BaseTool < MCP::Tool
      class << self
        # Convenience: access the Rails app and cached introspection
        def rails_app
          Rails.application
        end

        def config
          RailsAiContext.configuration
        end

        # Cache introspection results for the lifetime of the server process
        def cached_context
          @cached_context ||= RailsAiContext.introspect
        end

        def reset_cache!
          @cached_context = nil
        end
      end
    end
  end
end
