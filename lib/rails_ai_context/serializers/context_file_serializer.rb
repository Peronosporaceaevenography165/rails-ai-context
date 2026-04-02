# frozen_string_literal: true

require "fileutils"

module RailsAiContext
  module Serializers
    # Orchestrates writing context files to disk in various formats.
    # Supports: CLAUDE.md, AGENTS.md, .github/copilot-instructions.md, JSON
    # Also generates split rule files for AI tools that support them.
    #
    # Root files (CLAUDE.md, etc.) are wrapped in section markers so user content
    # outside the markers is preserved on re-generation. Set config.generate_root_files = false
    # to skip root files entirely and only produce split rules.
    class ContextFileSerializer
      attr_reader :context, :format

      FORMAT_MAP = {
        claude:    "CLAUDE.md",
        opencode:  "AGENTS.md",
        copilot:   ".github/copilot-instructions.md",
        json:      ".ai-context.json"
      }.freeze

      # Formats that produce only split rules (no root file).
      SPLIT_ONLY_FORMATS = %i[cursor].freeze

      ALL_FORMATS = (FORMAT_MAP.keys + SPLIT_ONLY_FORMATS).freeze

      BEGIN_MARKER = "<!-- BEGIN rails-ai-context -->"
      END_MARKER   = "<!-- END rails-ai-context -->"

      def initialize(context, format: :all)
        @context = context
        @format  = format
      end

      # Write context files, skipping unchanged ones.
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call
        formats = format == :all ? ALL_FORMATS : Array(format)
        output_dir = RailsAiContext.configuration.output_dir_for(Rails.application)
        generate_root = RailsAiContext.configuration.generate_root_files
        written = []
        skipped = []

        formats.each do |fmt|
          next if SPLIT_ONLY_FORMATS.include?(fmt)

          filename = FORMAT_MAP[fmt]
          unless filename
            valid = ALL_FORMATS.map(&:to_s).join(", ")
            raise ArgumentError, "Unknown format: #{fmt}. Valid formats: #{valid}"
          end

          # Skip root files when generate_root_files is false
          next unless generate_root

          filepath = File.join(output_dir, filename)
          FileUtils.mkdir_p(File.dirname(filepath))
          content = serialize(fmt)

          if fmt == :json
            write_plain(filepath, content, written, skipped)
          else
            write_with_markers(filepath, content, written, skipped)
          end
        end

        # Split rules are always generated regardless of generate_root_files
        generate_split_rules(formats, output_dir, written, skipped)

        { written: written, skipped: skipped }
      end

      private

      def serialize(fmt)
        case fmt
        when :json     then JsonSerializer.new(context).call
        when :claude   then ClaudeSerializer.new(context).call
        when :opencode then OpencodeSerializer.new(context).call
        when :copilot  then CopilotSerializer.new(context).call
        else MarkdownSerializer.new(context).call
        end
      end

      # JSON and other formats that don't support HTML comments
      def write_plain(filepath, content, written, skipped)
        if File.exist?(filepath) && File.read(filepath) == content
          skipped << filepath
        else
          atomic_write(filepath, content)
          written << filepath
        end
      end

      # Wrap content in section markers so user content is preserved
      def write_with_markers(filepath, content, written, skipped)
        marked_content = "#{BEGIN_MARKER}\n#{content}\n#{END_MARKER}\n"

        if File.exist?(filepath)
          existing = File.read(filepath)

          new_content = if existing.include?(BEGIN_MARKER) && existing.include?(END_MARKER)
            existing.sub(
              /#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}\n?/m,
              marked_content
            )
          else
            # File exists without markers — prepend our section so AI reads it first
            "#{marked_content}\n#{existing}"
          end

          if new_content == existing
            skipped << filepath
          else
            atomic_write(filepath, new_content)
            written << filepath
          end
        else
          atomic_write(filepath, marked_content)
          written << filepath
        end
      end

      # Write via temp file + rename to avoid partial writes from concurrent processes
      def atomic_write(filepath, content)
        dir = File.dirname(filepath)
        FileUtils.mkdir_p(dir)
        tmp = File.join(dir, ".#{File.basename(filepath)}.tmp")
        File.write(tmp, content)
        File.rename(tmp, filepath)
      end

      def generate_split_rules(formats, output_dir, written, skipped)
        if formats.include?(:claude)
          result = ClaudeRulesSerializer.new(context).call(output_dir)
          written.concat(result[:written])
          skipped.concat(result[:skipped])
        end

        if formats.include?(:cursor)
          result = CursorRulesSerializer.new(context).call(output_dir)
          written.concat(result[:written])
          skipped.concat(result[:skipped])
        end

        if formats.include?(:opencode)
          result = OpencodeRulesSerializer.new(context).call(output_dir)
          written.concat(result[:written])
          skipped.concat(result[:skipped])
        end

        if formats.include?(:copilot)
          result = CopilotInstructionsSerializer.new(context).call(output_dir)
          written.concat(result[:written])
          skipped.concat(result[:skipped])
        end
      end
    end
  end
end
