# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Orchestrates writing context files to disk in various formats.
    # Supports: CLAUDE.md, .cursorrules, .windsurfrules, .github/copilot-instructions.md, JSON
    class ContextFileSerializer
      attr_reader :context, :format

      FORMAT_MAP = {
        claude:    "CLAUDE.md",
        cursor:    ".cursorrules",
        windsurf:  ".windsurfrules",
        copilot:   ".github/copilot-instructions.md",
        json:      ".ai-context.json"
      }.freeze

      def initialize(context, format: :all)
        @context = context
        @format  = format
      end

      # Write context files and return list of files written
      # @return [Array<String>] file paths written
      def call
        formats = format == :all ? FORMAT_MAP.keys : Array(format)
        output_dir = RailsAiContext.configuration.output_dir_for(Rails.application)
        written = []

        formats.each do |fmt|
          filename = FORMAT_MAP[fmt]
          next unless filename

          filepath = File.join(output_dir, filename)

          # Ensure subdirectory exists (e.g. .github/)
          FileUtils.mkdir_p(File.dirname(filepath))

          content = serialize(fmt)
          File.write(filepath, content)
          written << filepath
        end

        written
      end

      private

      def serialize(fmt)
        case fmt
        when :json
          JsonSerializer.new(context).call
        else
          # All markdown-based formats use the same content
          MarkdownSerializer.new(context).call
        end
      end
    end
  end
end
