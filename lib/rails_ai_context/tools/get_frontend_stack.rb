# frozen_string_literal: true

module RailsAiContext
  module Tools
    class GetFrontendStack < BaseTool
      tool_name "rails_get_frontend_stack"
      description "Returns the app's frontend stack: framework, build tool, state management, TypeScript config, " \
        "component directories, and package manager. " \
        "Use when: scaffolding new frontend features, choosing libraries, or understanding the JS/TS build pipeline. " \
        "Key params: detail (summary for one-liner, standard for stack overview, full for config deep-dive)."

      input_schema(
        properties: {
          detail: {
            type: "string",
            enum: %w[summary standard full],
            description: "Level of detail: summary (one-liner), standard (stack overview + component counts), full (+ config details, path aliases, monorepo info)"
          }
        }
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(detail: "standard", server_context: nil) # rubocop:disable Metrics
        data = cached_context[:frontend_frameworks]

        unless data.is_a?(Hash) && !data[:error]
          return text_response(
            "No frontend framework data available. Ensure the :frontend_frameworks introspector is enabled in your " \
            "rails_ai_context configuration.\n\n" \
            "Example:\n```ruby\nRailsAiContext.configure do |config|\n  config.introspectors << :frontend_frameworks\nend\n```"
          )
        end

        case detail
        when "summary"
          text_response(build_summary(data))
        when "standard"
          text_response(build_standard(data))
        when "full"
          text_response(build_full(data))
        else
          text_response("Unknown detail level: #{detail}. Use summary, standard, or full.")
        end
      end

      class << self
        private

        def build_summary(data)
          parts = []
          parts << "#{data[:framework]}#{version_suffix(data[:version])}" if data[:framework]
          parts << data[:mounting_strategy] if data[:mounting_strategy]
          parts << data[:build_tool] if data[:build_tool]

          if data[:typescript].is_a?(Hash) && data[:typescript][:enabled]
            parts << "TypeScript"
          end

          parts << data[:state_management] if data[:state_management]

          total = total_component_count(data)
          parts << "(#{total} components)" if total > 0

          parts.any? ? parts.join(" + ") : "No frontend framework detected."
        end

        def build_standard(data)
          lines = [ "# Frontend Stack", "" ]

          lines << "- **Framework:** #{data[:framework]}#{version_suffix(data[:version])}" if data[:framework]
          lines << "- **Mounting strategy:** #{data[:mounting_strategy]}" if data[:mounting_strategy]
          lines << "- **Build tool:** #{data[:build_tool]}" if data[:build_tool]
          lines << "- **State management:** #{data[:state_management]}" if data[:state_management]
          lines << "- **Package manager:** #{data[:package_manager]}" if data[:package_manager]

          # TypeScript
          if data[:typescript].is_a?(Hash)
            ts = data[:typescript]
            if ts[:enabled]
              strict_label = ts[:strict] ? "strict" : "non-strict"
              lines << "- **TypeScript:** enabled (#{strict_label})"
            else
              lines << "- **TypeScript:** disabled"
            end
          end

          # Testing frameworks
          if data[:testing_frameworks].is_a?(Array) && data[:testing_frameworks].any?
            lines << "- **Testing:** #{data[:testing_frameworks].join(', ')}"
          end

          # Frontend roots with component counts
          if data[:frontend_roots].is_a?(Array) && data[:frontend_roots].any?
            lines << "" << "## Frontend Roots" << ""
            data[:frontend_roots].each do |root|
              count = root[:component_count] || 0
              lines << "- `#{root[:path]}` — #{count} components"
            end
          end

          lines.join("\n")
        end

        def build_full(data)
          lines = build_standard(data).lines.map(&:chomp)

          # TypeScript path aliases
          if data[:typescript].is_a?(Hash) && data[:typescript][:path_aliases].is_a?(Hash) && data[:typescript][:path_aliases].any?
            lines << "" << "## TypeScript Path Aliases" << ""
            data[:typescript][:path_aliases].each do |alias_name, target|
              lines << "- `#{alias_name}` -> `#{target}`"
            end
          end

          # Monorepo info
          if data[:monorepo].is_a?(Hash) && data[:monorepo].any?
            lines << "" << "## Monorepo" << ""
            lines << "- **Tool:** #{data[:monorepo][:tool]}" if data[:monorepo][:tool]
            if data[:monorepo][:workspaces].is_a?(Array) && data[:monorepo][:workspaces].any?
              lines << "- **Workspaces:** #{data[:monorepo][:workspaces].join(', ')}"
            end
          end

          # Component directory breakdown
          if data[:component_dirs].is_a?(Array) && data[:component_dirs].any?
            lines << "" << "## Component Directories" << ""
            data[:component_dirs].each do |dir|
              lines << "- `#{dir[:path]}` — #{dir[:count]} components"
            end
          end

          # Vite/build config plugins
          if data[:build_config].is_a?(Hash) && data[:build_config][:plugins].is_a?(Array) && data[:build_config][:plugins].any?
            lines << "" << "## Build Plugins" << ""
            data[:build_config][:plugins].each do |plugin|
              lines << "- #{plugin}"
            end
          end

          lines.join("\n")
        end

        def version_suffix(version)
          version ? " #{version}" : ""
        end

        def total_component_count(data)
          if data[:frontend_roots].is_a?(Array)
            data[:frontend_roots].sum { |r| r[:component_count] || 0 }
          elsif data[:component_dirs].is_a?(Array)
            data[:component_dirs].sum { |d| d[:count] || 0 }
          else
            0
          end
        end
      end
    end
  end
end
