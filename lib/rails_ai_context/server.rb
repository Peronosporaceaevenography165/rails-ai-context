# frozen_string_literal: true

require "mcp"

module RailsAiContext
  # Configures and starts an MCP server using the official Ruby SDK.
  # Registers all introspection tools and handles transport selection.
  class Server
    attr_reader :app, :transport_type

    TOOLS = [
      Tools::GetSchema,
      Tools::GetRoutes,
      Tools::GetModelDetails,
      Tools::GetGems,
      Tools::SearchCode,
      Tools::GetConventions
    ].freeze

    def initialize(app, transport: :stdio)
      @app = app
      @transport_type = transport
    end

    # Build and return the configured MCP::Server instance
    def build
      config = RailsAiContext.configuration

      server = MCP::Server.new(
        name: config.server_name,
        version: config.server_version,
        tools: TOOLS
      )

      server
    end

    # Start the MCP server with the configured transport
    def start
      server = build

      case transport_type
      when :stdio
        start_stdio(server)
      when :http, :streamable_http
        start_http(server)
      else
        raise ConfigurationError, "Unknown transport: #{transport_type}. Use :stdio or :http"
      end
    end

    private

    def start_stdio(server)
      transport = MCP::Server::Transports::StdioTransport.new(server)
      # Log to stderr so we don't pollute the JSON-RPC channel on stdout
      $stderr.puts "[rails-ai-context] MCP server started (stdio transport)"
      $stderr.puts "[rails-ai-context] Tools: #{TOOLS.map { |t| t.tool_name }.join(', ')}"
      transport.open
    end

    def start_http(server)
      config = RailsAiContext.configuration
      transport = MCP::Server::Transports::StreamableHTTPTransport.new(server)

      $stderr.puts "[rails-ai-context] MCP server starting on #{config.http_bind}:#{config.http_port}#{config.http_path}"
      $stderr.puts "[rails-ai-context] Tools: #{TOOLS.map { |t| t.tool_name }.join(', ')}"

      transport.start(
        host: config.http_bind,
        port: config.http_port,
        path: config.http_path
      )
    end
  end
end
