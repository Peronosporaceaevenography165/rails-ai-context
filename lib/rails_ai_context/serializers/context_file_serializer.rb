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

      # Write context files, skipping unchanged ones.
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call
        formats = format == :all ? FORMAT_MAP.keys : Array(format)
        output_dir = RailsAiContext.configuration.output_dir_for(Rails.application)
        written = []
        skipped = []

        formats.each do |fmt|
          filename = FORMAT_MAP[fmt]
          unless filename
            valid = FORMAT_MAP.keys.map(&:to_s).join(", ")
            raise ArgumentError, "Unknown format: #{fmt}. Valid formats: #{valid}"
          end

          filepath = File.join(output_dir, filename)

          # Ensure subdirectory exists (e.g. .github/)
          FileUtils.mkdir_p(File.dirname(filepath))

          content = serialize(fmt)

          if File.exist?(filepath) && File.read(filepath) == content
            skipped << filepath
          else
            File.write(filepath, content)
            written << filepath
          end
        end

        { written: written, skipped: skipped }
      end

      private

      def serialize(fmt)
        case fmt
        when :json     then JsonSerializer.new(context).call
        when :claude   then ClaudeSerializer.new(context).call
        when :cursor, :windsurf then RulesSerializer.new(context).call
        when :copilot  then CopilotSerializer.new(context).call
        else MarkdownSerializer.new(context).call
        end
      end
    end
  end
end
