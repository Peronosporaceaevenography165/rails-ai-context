# frozen_string_literal: true

module RailsAiContext
  class Engine < ::Rails::Engine
    isolate_namespace RailsAiContext

    # Register the MCP server after Rails finishes loading
    initializer "rails_ai_context.setup", after: :load_config_initializers do |app|
      # Make introspection available via Rails console
      Rails.application.config.rails_ai_context = RailsAiContext.configuration

      # Auto-mount HTTP transport if configured
      if RailsAiContext.configuration.auto_mount
        app.routes.append do
          mount RailsAiContext::Engine => RailsAiContext.configuration.http_path
        end
      end
    end

    # Register Rake tasks
    rake_tasks do
      load File.expand_path("../tasks/rails_ai_context.rake", __dir__)
    end

    # Register generators
    generators do
      require_relative "../generators/rails_ai_context/install/install_generator"
    end
  end
end
