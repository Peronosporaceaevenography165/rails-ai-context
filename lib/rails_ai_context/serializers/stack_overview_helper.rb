# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Shared helper for rendering stack overview lines from full-preset introspectors.
    # Include in any serializer that has a `context` reader and renders a project overview.
    module StackOverviewHelper
      # Returns an array of summary lines for full-preset introspectors.
      # Each line is only added if the introspector returned meaningful data.
      def full_preset_stack_lines(ctx = context)
        lines = []

        auth = ctx[:auth]
        if auth.is_a?(Hash) && !auth[:error]
          parts = []
          parts << "Devise" if auth.dig(:authentication, :devise)&.any?
          parts << "Rails 8 auth" if auth.dig(:authentication, :rails_auth)
          parts << "Pundit" if auth.dig(:authorization, :pundit)&.any?
          parts << "CanCanCan" if auth.dig(:authorization, :cancancan)
          lines << "- Auth: #{parts.join(' + ')}" if parts.any?
        end

        turbo = ctx[:turbo]
        if turbo.is_a?(Hash) && !turbo[:error]
          parts = []
          parts << "#{(turbo[:frames] || []).size} frames" if turbo[:frames]&.any?
          parts << "#{(turbo[:streams] || []).size} streams" if turbo[:streams]&.any?
          parts << "broadcasts" if turbo[:broadcasts]&.any?
          lines << "- Hotwire: #{parts.join(', ')}" if parts.any?
        end

        api = ctx[:api]
        if api.is_a?(Hash) && !api[:error]
          parts = []
          parts << "API-only" if api[:api_only]
          parts << "#{(api[:versions] || []).size} versions" if api[:versions]&.any?
          parts << "GraphQL" if api[:graphql]&.any?
          parts << api[:serializer_library] if api[:serializer_library]
          lines << "- API: #{parts.join(', ')}" if parts.any?
        end

        i18n_data = ctx[:i18n]
        if i18n_data.is_a?(Hash) && !i18n_data[:error]
          locales = i18n_data[:available_locales] || []
          lines << "- I18n: #{locales.size} locales (#{locales.first(5).join(', ')})" if locales.size > 1
        end

        storage = ctx[:active_storage]
        if storage.is_a?(Hash) && !storage[:error] && storage[:attachments]&.any?
          lines << "- Storage: ActiveStorage (#{storage[:attachments].size} models with attachments)"
        end

        action_text = ctx[:action_text]
        if action_text.is_a?(Hash) && !action_text[:error] && action_text[:rich_text_fields]&.any?
          lines << "- RichText: ActionText (#{action_text[:rich_text_fields].size} fields)"
        end

        assets = ctx[:assets]
        if assets.is_a?(Hash) && !assets[:error]
          parts = []
          parts << assets[:pipeline] if assets[:pipeline]
          parts << assets[:js_bundler] if assets[:js_bundler]
          parts << assets[:css_framework] if assets[:css_framework]
          lines << "- Assets: #{parts.join(', ')}" if parts.any?
        end

        engines = ctx[:engines]
        if engines.is_a?(Hash) && !engines[:error] && engines[:mounted]&.any?
          names = engines[:mounted].map { |e| e[:name] || e[:engine] }.compact.first(5)
          lines << "- Engines: #{names.join(', ')}" if names.any?
        end

        multi_db = ctx[:multi_database]
        if multi_db.is_a?(Hash) && !multi_db[:error] && multi_db[:databases]&.size.to_i > 1
          db_names = multi_db[:databases].is_a?(Array) ? multi_db[:databases].map { |d| d[:name] } : multi_db[:databases].keys
          lines << "- Databases: #{multi_db[:databases].size} (#{db_names.first(3).join(', ')})"
        end

        components = ctx[:components]
        if components.is_a?(Hash) && !components[:error] && components.dig(:summary, :total).to_i > 0
          summary = components[:summary]
          parts = [ "#{summary[:total]} components" ]
          parts << "#{summary[:view_component]} ViewComponent" if summary[:view_component].to_i > 0
          parts << "#{summary[:phlex]} Phlex" if summary[:phlex].to_i > 0
          lines << "- Components: #{parts.join(', ')}"
        end

        a11y = ctx[:accessibility]
        if a11y.is_a?(Hash) && !a11y[:error] && a11y[:summary]
          score = a11y.dig(:summary, :score_label)
          lines << "- Accessibility: #{score}" if score
        end

        perf = ctx[:performance]
        if perf.is_a?(Hash) && !perf[:error] && perf[:summary]
          total = perf.dig(:summary, :total_issues).to_i
          lines << "- Performance: #{total} issues detected" if total > 0
        end

        lines
      end
    end
  end
end
