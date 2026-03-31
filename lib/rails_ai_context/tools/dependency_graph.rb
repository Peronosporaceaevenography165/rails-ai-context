# frozen_string_literal: true

module RailsAiContext
  module Tools
    class DependencyGraph < BaseTool
      tool_name "rails_dependency_graph"
      description "Generates a dependency graph showing how models, services, and controllers " \
        "connect. Output as Mermaid diagram syntax or plain text. " \
        "Use when: understanding feature architecture, tracing data flow, planning refactors. " \
        "Key params: model (center graph on model), depth (1-3), format (mermaid/text)."

      input_schema(
        properties: {
          model: {
            type: "string",
            description: "Center the graph on this model (e.g., 'User'). Without this, shows all models."
          },
          depth: {
            type: "integer",
            description: "How many hops from the center model (1-3, default: 2)"
          },
          format: {
            type: "string",
            enum: %w[mermaid text],
            description: "Output format: mermaid (diagram syntax) or text (plain)"
          }
        }
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      MAX_NODES = 50

      def self.call(model: nil, depth: 2, format: "mermaid", server_context: nil)
        models_data = cached_context[:models]

        unless models_data.is_a?(Hash) && !models_data[:error]
          return text_response("No model data available. Ensure :models introspector is enabled.")
        end

        model = model.to_s.strip if model
        depth = [ [ depth.to_i, 1 ].max, 3 ].min

        # Build adjacency list from model associations
        graph = build_graph(models_data)

        if model
          # Filter to subgraph centered on the model
          model_key = find_model_key(model, graph.keys)
          unless model_key
            return not_found_response("model", model, graph.keys, recovery_tool: "rails_dependency_graph")
          end
          subgraph = extract_subgraph(graph, model_key, depth)
        else
          subgraph = graph
        end

        # Limit nodes
        if subgraph.size > MAX_NODES
          subgraph = subgraph.first(MAX_NODES).to_h
        end

        case format
        when "mermaid"
          text_response(render_mermaid(subgraph, model))
        else
          text_response(render_text(subgraph, model))
        end
      end

      class << self
        private

        def build_graph(models_data)
          graph = {}

          models_data.each do |model_name, data|
            next unless data.is_a?(Hash) && !data[:error]
            name = model_name.to_s

            associations = data[:associations] || []
            edges = associations.filter_map do |assoc|
              target = assoc[:class_name] || assoc[:name]&.to_s&.classify
              next unless target
              {
                type: assoc[:macro] || assoc[:type],
                target: target,
                through: assoc[:through],
                polymorphic: assoc[:polymorphic]
              }
            end

            graph[name] = edges
          end

          graph
        end

        def find_model_key(query, keys)
          keys.find { |k| k.downcase == query.downcase } ||
            keys.find { |k| k.underscore.downcase == query.downcase }
        end

        def extract_subgraph(graph, center, depth)
          visited = Set.new
          queue = [ [ center, 0 ] ]
          subgraph = {}

          while queue.any?
            current, d = queue.shift
            next if visited.include?(current) || d > depth
            visited.add(current)

            edges = graph[current] || []
            subgraph[current] = edges

            edges.each do |edge|
              queue << [ edge[:target], d + 1 ] unless visited.include?(edge[:target])
            end

            # Also find reverse associations pointing to current
            graph.each do |model, model_edges|
              next if visited.include?(model)
              if model_edges.any? { |e| e[:target] == current }
                queue << [ model, d + 1 ]
              end
            end
          end

          subgraph
        end

        def render_mermaid(graph, center)
          lines = [ "# Dependency Graph", "" ]
          lines << "```mermaid"
          lines << "graph LR"

          if center
            lines << "  style #{sanitize(center)} fill:#f9f,stroke:#333,stroke-width:2px"
          end

          rendered = Set.new
          graph.each do |model, edges|
            edges.each do |edge|
              key = "#{model}->#{edge[:target]}:#{edge[:type]}"
              next if rendered.include?(key)
              rendered.add(key)

              arrow = case edge[:type].to_s
              when "has_many", "has_and_belongs_to_many" then "-->|has_many|"
              when "belongs_to" then "-->|belongs_to|"
              when "has_one" then "-->|has_one|"
              else "-->|#{edge[:type]}|"
              end

              through = edge[:through] ? " (through: #{edge[:through]})" : ""
              lines << "  #{sanitize(model)} #{arrow} #{sanitize(edge[:target])}"
            end
          end

          lines << "```"
          lines << ""
          lines << "**Models:** #{graph.keys.size} | **Associations:** #{graph.values.sum(&:size)}"

          lines.join("\n")
        end

        def render_text(graph, center)
          lines = [ "# Dependency Graph", "" ]

          if center
            lines << "Centered on: #{center}"
            lines << ""
          end

          graph.each do |model, edges|
            lines << "## #{model}"
            if edges.empty?
              lines << "  (no associations)"
            else
              edges.each do |edge|
                through = edge[:through] ? " through #{edge[:through]}" : ""
                poly = edge[:polymorphic] ? " (polymorphic)" : ""
                lines << "  #{edge[:type]} → #{edge[:target]}#{through}#{poly}"
              end
            end
            lines << ""
          end

          lines << "**Models:** #{graph.keys.size} | **Associations:** #{graph.values.sum(&:size)}"

          lines.join("\n")
        end

        def sanitize(name)
          sanitized = name.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
          # Mermaid node IDs must start with a letter
          sanitized = "M#{sanitized}" if sanitized.match?(/\A\d/)
          sanitized
        end
      end
    end
  end
end
