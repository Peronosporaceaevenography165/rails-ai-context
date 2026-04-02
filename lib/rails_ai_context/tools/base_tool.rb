# frozen_string_literal: true

require "mcp"

module RailsAiContext
  module Tools
    # Base class for all MCP tools exposed by rails-ai-context.
    # Inherits from the official MCP::Tool to get schema validation,
    # annotations, and protocol compliance for free.
    class BaseTool < MCP::Tool
      # Shared cache across all tool subclasses, protected by a Mutex
      # for thread safety in multi-threaded servers (e.g., Puma).
      SHARED_CACHE = { mutex: Mutex.new }

      # Session-level context tracking. Lets AI avoid redundant queries
      # by recording what tools have been called with what params.
      # In-memory only — resets on server restart (matches conversation lifecycle).
      SESSION_CONTEXT = { mutex: Mutex.new, queries: {} }

      class << self
        # Convenience: access the Rails app and cached introspection
        def rails_app
          Rails.application
        end

        def config
          RailsAiContext.configuration
        end

        # Cache introspection results with TTL + fingerprint invalidation.
        # Uses SHARED_CACHE so all tool subclasses share one introspection
        # result instead of each caching independently.
        def cached_context
          SHARED_CACHE[:mutex].synchronize do
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            ttl = RailsAiContext.configuration.cache_ttl

            if SHARED_CACHE[:context] && (now - SHARED_CACHE[:timestamp]) < ttl && !Fingerprinter.changed?(rails_app, SHARED_CACHE[:fingerprint])
              return SHARED_CACHE[:context]
            end

            SHARED_CACHE[:context] = RailsAiContext.introspect
            SHARED_CACHE[:timestamp] = now
            SHARED_CACHE[:fingerprint] = Fingerprinter.compute(rails_app)
            SHARED_CACHE[:context]
          end
        end

        def reset_cache!
          SHARED_CACHE[:mutex].synchronize do
            SHARED_CACHE.delete(:context)
            SHARED_CACHE.delete(:timestamp)
            SHARED_CACHE.delete(:fingerprint)
          end
        end

        # Reset the shared cache. Used by LiveReload to invalidate on file change.
        def reset_all_caches!
          reset_cache!
          session_reset!
        end

        # ── Session context helpers ──────────────────────────────────────

        def session_record(tool_name, params, summary = nil)
          SESSION_CONTEXT[:mutex].synchronize do
            key = session_key(tool_name, params)
            SESSION_CONTEXT[:queries][key] = {
              tool: tool_name.to_s,
              params: params,
              timestamp: Time.now.iso8601,
              summary: summary
            }
          end
        end

        def session_queried?(tool_name, **params)
          SESSION_CONTEXT[:mutex].synchronize do
            SESSION_CONTEXT[:queries].key?(session_key(tool_name, params))
          end
        end

        def session_queries
          SESSION_CONTEXT[:mutex].synchronize do
            SESSION_CONTEXT[:queries].values.dup
          end
        end

        def session_reset!
          SESSION_CONTEXT[:mutex].synchronize do
            SESSION_CONTEXT[:queries].clear
          end
        end

        # Auto-compress: if text exceeds 85% of max, call the fallback lambda for a shorter version
        def auto_compress(full_text, &fallback)
          max = config.max_tool_response_chars
          return full_text if !max || full_text.length <= (max * 0.85).to_i
          fallback ? fallback.call : full_text
        end

        # Structured not-found error with fuzzy suggestion and recovery hint.
        # Helps AI agents self-correct without retrying blind.
        def not_found_response(type, name, available, recovery_tool: nil)
          suggestion = find_closest_match(name, available)
          # Don't suggest the exact same string the user typed — that's useless
          suggestion = nil if suggestion == name
          lines = [ "#{type} '#{name}' not found." ]
          lines << "Did you mean '#{suggestion}'?" if suggestion
          lines << "Available: #{available.first(20).join(', ')}#{"..." if available.size > 20}"
          lines << "_Recovery: #{recovery_tool}_" if recovery_tool
          text_response(lines.join("\n"))
        end

        # Fuzzy match: find the closest available name by exact, underscore, substring, or prefix
        def find_closest_match(input, available)
          return nil if available.empty?
          downcased = input.downcase
          underscored = input.underscore.downcase

          # Exact case-insensitive match (including underscore/classify variants)
          exact = available.find do |a|
            a_down = a.downcase
            a_under = a.underscore.downcase
            a_down == downcased || a_under == underscored || a_down == underscored || a_under == downcased
          end
          return exact if exact

          # Substring match — prefer shortest (most specific) to avoid cook → cook_comments
          substring_matches = available.select { |a| a.downcase.include?(downcased) || downcased.include?(a.downcase) }
          return substring_matches.min_by(&:length) if substring_matches.any?

          # Prefix match
          available.find { |a| a.downcase.start_with?(downcased[0..2]) }
        end

        # Cache key for paginated responses — lets agents detect stale data between pages
        def cache_key
          SHARED_CACHE[:fingerprint] || "none"
        end

        # App size classification — tools use this to auto-tune pagination and detail
        # small: <15 models, medium: 15-50 models, large: 50+ models
        def app_size
          ctx = SHARED_CACHE[:context]
          return :medium unless ctx

          model_count = ctx[:models]&.size || 0
          table_count = ctx.dig(:schema, :tables)&.size || 0
          biggest = [ model_count, table_count ].max

          if biggest > 50 then :large
          elsif biggest > 15 then :medium
          else :small
          end
        end

        # Helper: wrap text in an MCP::Tool::Response with safety-net truncation.
        # Auto-records the call in session context so session_context(action:"status") works.
        def text_response(text)
          # Auto-track: record this tool call in session context (skip SessionContext itself to avoid recursion)
          if respond_to?(:tool_name) && tool_name != "rails_session_context"
            summary = text.lines.first&.strip&.truncate(80)
            session_record(tool_name, {}, summary)
          end

          max = RailsAiContext.configuration.max_tool_response_chars
          if max && text.length > max
            truncated = text[0...max]
            truncated += "\n\n---\n_Response truncated (#{text.length} chars). Use `detail:\"summary\"` for an overview, or filter by a specific item (e.g. `table:\"users\"`)._"
            MCP::Tool::Response.new([ { type: "text", text: truncated } ])
          else
            MCP::Tool::Response.new([ { type: "text", text: text } ])
          end
        end

        private

        def session_key(tool_name, params)
          normalized = tool_name.to_s.sub(/\Arails_/, "")
          param_str = params.is_a?(Hash) ? params.sort_by { |k, _| k.to_s }.map { |k, v| "#{k}:#{v}" }.join(",") : params.to_s
          "#{normalized}:#{param_str}"
        end
      end
    end
  end
end
