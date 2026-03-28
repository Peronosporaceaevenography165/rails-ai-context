# frozen_string_literal: true

module RailsAiContext
  module Tools
    class PerformanceCheck < BaseTool
      tool_name "rails_performance_check"
      description "Static analysis for Rails performance anti-patterns: N+1 query risks, " \
        "missing counter_cache, Model.all in controllers, missing foreign key indexes, " \
        "eager loading candidates. " \
        "Use when: reviewing code for performance, before deploying, or investigating slow pages. " \
        "Key params: model (filter by model), category (filter by issue type), detail level."

      input_schema(
        properties: {
          model: {
            type: "string",
            description: "Filter results to a specific model (e.g., 'User', 'Post')"
          },
          category: {
            type: "string",
            enum: %w[n_plus_one counter_cache indexes model_all eager_load all],
            description: "Filter by issue category (default: all)"
          },
          detail: {
            type: "string",
            enum: %w[summary standard full],
            description: "Level of detail: summary (counts), standard (issues + suggestions), full (+ code context)"
          }
        }
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(model: nil, category: "all", detail: "standard", server_context: nil)
        data = cached_context[:performance]

        unless data.is_a?(Hash) && !data[:error]
          return text_response("No performance data available. Ensure :performance introspector is enabled.")
        end

        model = model.to_s.strip if model

        # Validate model exists if specified
        if model && !model.empty?
          models_data = cached_context[:models]
          if models_data.is_a?(Hash) && !models_data[:error]
            model_names = models_data.keys.map(&:to_s)
            unless model_names.any? { |m| m.downcase == model.downcase }
              return not_found_response("model", model, model_names, recovery_tool: "rails_performance_check")
            end
          end
        end

        lines = [ "# Performance Analysis", "" ]

        summary = data[:summary] || {}
        lines << "**Total issues found:** #{summary[:total_issues] || 0}"
        lines << ""

        if detail == "summary"
          lines << "- N+1 risks: #{summary[:n_plus_one_risks] || 0}"
          lines << "- Missing counter_cache: #{summary[:missing_counter_cache] || 0}"
          lines << "- Missing FK indexes: #{summary[:missing_fk_indexes] || 0}"
          lines << "- Model.all in controllers: #{summary[:model_all_in_controllers] || 0}"
          lines << "- Eager load candidates: #{summary[:eager_load_candidates] || 0}"
        else
          if category == "all" || category == "n_plus_one"
            lines.concat(render_section("N+1 Query Risks", data[:n_plus_one_risks], model, detail))
          end
          if category == "all" || category == "counter_cache"
            lines.concat(render_section("Missing counter_cache", data[:missing_counter_cache], model, detail))
          end
          if category == "all" || category == "indexes"
            lines.concat(render_section("Missing FK Indexes", data[:missing_fk_indexes], model, detail))
          end
          if category == "all" || category == "model_all"
            lines.concat(render_section("Model.all in Controllers", data[:model_all_in_controllers], model, detail))
          end
          if category == "all" || category == "eager_load"
            lines.concat(render_section("Eager Load Candidates", data[:eager_load_candidates], model, detail))
          end
        end

        if summary[:total_issues] == 0
          lines << "No performance issues detected. Your app looks good!"
        end

        text_response(lines.join("\n"))
      end

      class << self
        private

        def render_section(title, items, model_filter, detail)
          return [] unless items&.any?

          filtered = if model_filter
            filter_lower = model_filter.downcase
            # Underscore BEFORE downcase to handle CamelCase → snake_case correctly
            # "BrandProfile" → "brand_profile" → "brand_profiles"
            table_form = begin
              model_filter.underscore.pluralize.downcase
            rescue
              filter_lower
            end
            items.select { |i|
              (i[:model]&.downcase == filter_lower) ||
              (i[:table]&.downcase == table_form) ||
              (i[:table]&.downcase == filter_lower) ||
              (i[:table]&.downcase == model_filter.underscore.downcase)
            }
          else
            items
          end

          return [] if filtered.empty?

          lines = [ "## #{title} (#{filtered.size})", "" ]

          filtered.each do |item|
            lines << "- **#{item[:model] || item[:table] || "Unknown"}**"
            lines << "  #{item[:suggestion]}" if item[:suggestion]
            if detail == "full"
              lines << "  Controller: #{item[:controller]}" if item[:controller]
              lines << "  Association: #{item[:association]}" if item[:association]
              lines << "  Column: #{item[:column]}" if item[:column]
              lines << "  Associations: #{item[:associations]&.join(', ')}" if item[:associations]
            end
            lines << ""
          end

          lines
        end
      end
    end
  end
end
