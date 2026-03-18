# frozen_string_literal: true

module RailsAiContext
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install rails-ai-context: creates initializer and generates initial context files."

      def create_initializer
        create_file "config/initializers/rails_ai_context.rb", <<~RUBY
          # frozen_string_literal: true

          RailsAiContext.configure do |config|
            # MCP server name (shown to AI clients)
            # config.server_name = "rails-ai-context"

            # Auto-mount HTTP MCP endpoint at /mcp
            # Set to true if you want remote MCP clients to connect
            # config.auto_mount = false
            # config.http_path  = "/mcp"
            # config.http_port  = 6029

            # Models to exclude from introspection
            # config.excluded_models += %w[AdminUser InternalThing]

            # Paths to exclude from code search
            # config.excluded_paths += %w[vendor/bundle]
          end
        RUBY

        say "Created config/initializers/rails_ai_context.rb", :green
      end

      def add_to_gitignore
        gitignore = Rails.root.join(".gitignore")
        return unless File.exist?(gitignore)

        content = File.read(gitignore)
        append = []
        append << ".ai-context.json" unless content.include?(".ai-context.json")

        if append.any?
          File.open(gitignore, "a") do |f|
            f.puts ""
            f.puts "# rails-ai-context (JSON cache — markdown files should be committed)"
            append.each { |line| f.puts line }
          end
          say "Updated .gitignore", :green
        end
      end

      def generate_context_files
        say ""
        say "Generating AI context files...", :yellow

        if Rails.application
          require "rails_ai_context"
          context = RailsAiContext.introspect
          files = RailsAiContext.generate_context(format: :all)
          files.each { |f| say "  Created #{f}", :green }
        else
          say "  Skipped (Rails app not fully loaded). Run `rails ai:context` after install.", :yellow
        end
      end

      def show_instructions
        say ""
        say "=" * 50, :cyan
        say " rails-ai-context installed!", :cyan
        say "=" * 50, :cyan
        say ""
        say "Quick start:", :yellow
        say "  rails ai:context     # Regenerate context files"
        say "  rails ai:serve       # Start MCP server (stdio)"
        say "  rails ai:inspect     # Print introspection summary"
        say ""
        say "For Claude Code, add to your claude_desktop_config.json:", :yellow
        say '  { "mcpServers": { "rails": { "command": "rails", "args": ["ai:serve"], "cwd": "/path/to/your/app" } } }'
        say ""
        say "Commit CLAUDE.md and .cursorrules so your team benefits!", :green
      end
    end
  end
end
