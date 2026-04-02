# frozen_string_literal: true

module RailsAiContext
  module Tools
    class SessionContext < BaseTool
      tool_name "rails_session_context"
      description "Track what you've already queried to avoid redundant calls. " \
        "Use action:\"status\" to see what tools you've called, action:\"summary\" for a compressed recap, " \
        "action:\"reset\" to clear session, or mark:\"tool:param\" to record a query. " \
        "Helps maintain focus during long development sessions."

      input_schema(
        properties: {
          action: {
            type: "string",
            enum: %w[status summary reset],
            description: "status: list queried tools with timestamps. summary: compressed recap. reset: clear session."
          },
          mark: {
            type: "string",
            description: "Mark a tool+params as already queried (e.g., 'get_schema:users', 'get_model_details:User')."
          }
        }
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

      def self.call(action: nil, mark: nil, server_context: nil)
        unless action || mark
          return text_response("Provide `action` (status/summary/reset) or `mark` (tool:param to record).")
        end

        if mark
          tool, params = parse_mark(mark)
          session_record(tool, params)
          return text_response("Marked `#{tool}` with params `#{params}` as queried.")
        end

        case action
        when "status"
          render_status
        when "summary"
          render_summary
        when "reset"
          session_reset!
          text_response("Session cleared. All query records removed.")
        else
          text_response("Unknown action: #{action}. Use status, summary, or reset.")
        end
      rescue => e
        text_response("Session context error: #{e.message}")
      end

      class << self
        private

        def parse_mark(mark_string)
          parts = mark_string.split(":", 2)
          tool = parts[0]&.strip
          params = parts[1]&.strip || ""
          [ tool, params ]
        end

        def render_status
          queries = session_queries
          if queries.empty?
            return text_response("# Session Context\n\nNo queries recorded yet. Tools will be tracked as you use them.\n\n_Use `mark:\"tool:params\"` to manually record a query._\n_Note: CLI (`rails ai:tool`) runs each call in a separate process — session tracking only works via MCP._")
          end

          lines = [ "# Session Context (#{queries.size} queries)", "" ]
          lines << "| Tool | Params | When |"
          lines << "|------|--------|------|"

          queries.sort_by { |q| q[:timestamp] }.each do |q|
            ago = time_ago(q[:timestamp])
            params_str = q[:params].is_a?(Hash) ? q[:params].map { |k, v| "#{k}:#{v}" }.join(", ") : q[:params].to_s
            params_display = params_str.empty? ? "-" : params_str.truncate(40)
            lines << "| `#{q[:tool]}` | #{params_display} | #{ago} |"
          end

          lines << ""
          lines << "_Use `action:\"reset\"` to clear, or `action:\"summary\"` for a compressed recap._"
          lines << "_Note: CLI (`rails ai:tool`) runs each call in a separate process — session tracking only works via MCP._"
          text_response(lines.join("\n"))
        end

        def render_summary
          queries = session_queries
          if queries.empty?
            return text_response("No queries recorded yet.")
          end

          lines = [ "# Session Summary", "" ]
          lines << "You have queried #{queries.size} tool(s) in this session:"
          lines << ""

          # Group by tool name
          by_tool = queries.group_by { |q| q[:tool] }
          by_tool.each do |tool, calls|
            params_list = calls.map { |c|
              p = c[:params]
              p.is_a?(Hash) ? p.map { |k, v| "#{k}:#{v}" }.join(", ") : p.to_s
            }.reject(&:empty?)

            if params_list.any?
              lines << "- **#{tool}** (#{calls.size}x): #{params_list.uniq.join('; ')}"
            else
              lines << "- **#{tool}** (#{calls.size}x)"
            end
          end

          lines << ""
          lines << "_Avoid re-querying these. Use `action:\"status\"` for timestamps._"
          text_response(lines.join("\n"))
        end

        def time_ago(iso_timestamp)
          diff = Time.now - Time.parse(iso_timestamp)
          if diff < 60
            "#{diff.to_i}s ago"
          elsif diff < 3600
            "#{(diff / 60).to_i}m ago"
          else
            "#{(diff / 3600).to_i}h ago"
          end
        rescue
          iso_timestamp
        end
      end
    end
  end
end
