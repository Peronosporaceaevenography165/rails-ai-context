# frozen_string_literal: true

require "open3"
require "erb"

module RailsAiContext
  module Tools
    class Validate < BaseTool
      tool_name "rails_validate"
      description "Validate syntax of multiple files at once (Ruby, ERB, JavaScript). Replaces separate ruby -c, erb check, and node -c calls. Returns pass/fail for each file with error details."

      def self.max_files
        RailsAiContext.configuration.max_validate_files
      end

      input_schema(
        properties: {
          files: {
            type: "array",
            items: { type: "string" },
            description: "File paths relative to Rails root (e.g. ['app/models/cook.rb', 'app/views/cooks/index.html.erb'])"
          }
        },
        required: %w[files]
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(files:, server_context: nil)
        if files.empty?
          return text_response("No files provided.")
        end

        if files.size > max_files
          return text_response("Too many files (#{files.size}). Maximum is #{max_files} per call.")
        end

        results = []
        passed = 0
        total = 0

        files.each do |file|
          full_path = Rails.root.join(file)

          # Path traversal protection
          unless File.exist?(full_path)
            results << "\u2717 #{file} \u2014 file not found"
            total += 1
            next
          end

          begin
            real = File.realpath(full_path)
            unless real.start_with?(File.realpath(Rails.root))
              results << "\u2717 #{file} \u2014 path not allowed (outside Rails root)"
              total += 1
              next
            end
          rescue Errno::ENOENT
            results << "\u2717 #{file} \u2014 file not found"
            total += 1
            next
          end

          total += 1

          if file.end_with?(".rb")
            ok, msg = validate_ruby(full_path)
          elsif file.end_with?(".html.erb") || file.end_with?(".erb")
            ok, msg = validate_erb(full_path)
          elsif file.end_with?(".js")
            ok, msg = validate_javascript(full_path)
          else
            results << "- #{file} \u2014 skipped (unsupported file type)"
            total -= 1
            next
          end

          if ok
            results << "\u2713 #{file} \u2014 syntax OK"
            passed += 1
          else
            results << "\u2717 #{file} \u2014 #{msg}"
          end
        end

        output = results.join("\n")
        output += "\n\n#{passed}/#{total} files passed"

        text_response(output)
      end

      # Validate Ruby syntax via `ruby -c` (no shell — uses Open3 array form)
      private_class_method def self.validate_ruby(full_path)
        result, status = Open3.capture2e("ruby", "-c", full_path.to_s)
        if status.success?
          [ true, nil ]
        else
          # Show up to 5 non-empty error lines for full context (ruby -c gives multi-line errors)
          error_lines = result.lines
            .reject { |l| l.strip.empty? || l.include?("Syntax OK") }
            .first(5)
            .map { |l| l.strip.sub(full_path.to_s, File.basename(full_path.to_s)) }
          error = error_lines.any? ? error_lines.join("\n") : "syntax error"
          [ false, error ]
        end
      end

      # Validate ERB by compiling to Ruby source then syntax-checking the result.
      # Catches missing <% end %>, unclosed blocks, and mismatched do/end.
      #
      # Two key pre-processing steps avoid false positives:
      # 1. Convert `<%= ... %>` to `<% ... %>` — prevents the `_buf << ( helper do ).to_s`
      #    ambiguity that standard ERB compilation creates for block-form helpers
      #    like `<%= link_to ... do %>`, `<%= form_with ... do |f| %>`, etc.
      # 2. Wrap compiled source in a method def — makes `yield` syntactically valid.
      private_class_method def self.validate_erb(full_path)
        return [ false, "file too large" ] if File.size(full_path) > RailsAiContext.configuration.max_file_size

        content = File.binread(full_path).force_encoding("UTF-8")

        # Pre-process: convert output tags to non-output for syntax-only checking.
        # This is safe because we only check structure (do/end, if/end matching),
        # not whether output is correct.
        processed = content.gsub("<%=", "<%")

        # Compile ERB to Ruby, wrapped in a method so `yield` is valid syntax.
        # Force UTF-8 on .src output — ERB may return ASCII-8BIT which breaks
        # concatenation with UTF-8 strings when non-ASCII bytes (emoji, etc.) are present.
        erb_src = +ERB.new(processed).src
        erb_src.force_encoding("UTF-8")
        compiled = "# encoding: utf-8\ndef __erb_syntax_check\n#{erb_src}\nend"

        check_result, check_status = Open3.capture2e("ruby", "-c", "-", stdin_data: compiled)
        if check_status.success?
          [ true, nil ]
        else
          # Adjust line numbers: subtract 1 for the wrapper def line
          error = check_result.lines
            .reject { |l| l.strip.empty? || l.include?("Syntax OK") }
            .first(5)
            .map { |l| l.strip.sub(/-:(\d+):/) { "ruby: -:#{$1.to_i - 1}:" } }
          msg = error.any? ? error.join("\n") : "ERB syntax error"
          [ false, msg ]
        end
      rescue => e
        [ false, "ERB check error: #{e.message}" ]
      end

      # Validate JavaScript syntax via `node -c` (no shell — uses Open3 array form)
      private_class_method def self.validate_javascript(full_path)
        @node_available = system("which", "node", out: File::NULL, err: File::NULL) if @node_available.nil?

        if @node_available
          result, status = Open3.capture2e("node", "-c", full_path.to_s)
          if status.success?
            [ true, nil ]
          else
            # Show up to 3 non-empty error lines for context
            error_lines = result.lines
              .reject { |l| l.strip.empty? }
              .first(3)
              .map { |l| l.strip.sub(full_path.to_s, File.basename(full_path.to_s)) }
            error = error_lines.any? ? error_lines.join("\n") : "syntax error"
            [ false, error ]
          end
        else
          validate_javascript_fallback(full_path)
        end
      end

      # Basic JavaScript validation when node is not available.
      # Checks for unmatched braces, brackets, and parentheses.
      private_class_method def self.validate_javascript_fallback(full_path)
        return [ false, "file too large for basic validation" ] if File.size(full_path) > RailsAiContext.configuration.max_file_size
        content = File.read(full_path)
        stack = []
        openers = { "{" => "}", "[" => "]", "(" => ")" }
        closers = { "}" => "{", "]" => "[", ")" => "(" }
        in_string = nil
        in_line_comment = false
        in_block_comment = false
        prev_char = nil

        content.each_char.with_index do |char, i|
          if in_line_comment
            in_line_comment = false if char == "\n"
            prev_char = char
            next
          end

          if in_block_comment
            if prev_char == "*" && char == "/"
              in_block_comment = false
            end
            prev_char = char
            next
          end

          if in_string
            if char == in_string && prev_char != "\\"
              in_string = nil
            end
            prev_char = char
            next
          end

          case char
          when '"', "'", "`"
            in_string = char
          when "/"
            if prev_char == "/"
              in_line_comment = true
              stack.pop if stack.last == "/" # remove the first / we may have pushed
            end
          when "*"
            if prev_char == "/"
              in_block_comment = true
            end
          else
            if openers.key?(char)
              stack << char
            elsif closers.key?(char)
              if stack.empty? || stack.last != closers[char]
                line_num = content[0..i].count("\n") + 1
                return [ false, "line #{line_num}: unmatched '#{char}'" ]
              end
              stack.pop
            end
          end

          prev_char = char
        end

        if stack.empty?
          [ true, nil ]
        else
          [ false, "unmatched '#{stack.last}' (node not available, basic check only)" ]
        end
      end
    end
  end
end
