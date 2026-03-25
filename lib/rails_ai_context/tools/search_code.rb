# frozen_string_literal: true

require "open3"

module RailsAiContext
  module Tools
    class SearchCode < BaseTool
      tool_name "rails_search_code"
      description "Search the Rails codebase by regex pattern, returning matching lines with file paths and line numbers. " \
        "Use when: finding where a method is called, locating class definitions, or tracing how a feature is implemented. " \
        "Requires pattern:\"def activate\". Narrow with path:\"app/models\" and file_type:\"rb\"."

      def self.max_results_cap
        RailsAiContext.configuration.max_search_results
      end

      input_schema(
        properties: {
          pattern: {
            type: "string",
            description: "Search pattern (regex supported)."
          },
          path: {
            type: "string",
            description: "Subdirectory to search in (e.g. 'app/models', 'config'). Default: entire app."
          },
          file_type: {
            type: "string",
            description: "Filter by file extension (e.g. 'rb', 'js', 'erb'). Default: all files."
          },
          match_type: {
            type: "string",
            enum: %w[any definition class call],
            description: "Filter match type. any: all matches (default). definition: only `def method_name` lines. class: only `class/module Name` lines. call: only call sites (excludes the definition)."
          },
          exact_match: {
            type: "boolean",
            description: "Match whole words only (wraps pattern in \\b word boundaries). Default: false."
          },
          exclude_tests: {
            type: "boolean",
            description: "Exclude test/spec files from results. Default: false."
          },
          group_by_file: {
            type: "boolean",
            description: "Group results by file with match counts. Default: false."
          },
          offset: {
            type: "integer",
            description: "Skip this many results for pagination. Default: 0."
          },
          context_lines: {
            type: "integer",
            description: "Lines of context before and after each match (like grep -C). Default: 2, max: 5."
          }
        },
        required: [ "pattern" ]
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(pattern:, path: nil, file_type: nil, match_type: "any", exact_match: false, exclude_tests: false, group_by_file: false, offset: 0, context_lines: 2, server_context: nil) # rubocop:disable Metrics
        root = Rails.root.to_s
        original_pattern = pattern

        # Reject empty or whitespace-only patterns
        if pattern.nil? || pattern.strip.empty?
          return text_response("Pattern is required. Provide a search term or regex.")
        end

        # Apply exact_match word boundaries
        pattern = "\\b#{pattern}\\b" if exact_match

        # Apply match_type filter to pattern
        search_pattern = case match_type
        when "definition"
          cleaned = pattern.sub(/\A\s*def\s+/, "")
          "^\\s*def\\s+(self\\.)?#{cleaned}"
        when "class"
          cleaned = pattern.sub(/\A\s*(class|module)\s+/, "")
          "^\\s*(class|module)\\s+\\w*#{cleaned}"
        when "call"
          pattern
        else
          pattern
        end

        # Validate regex syntax early
        begin
          Regexp.new(search_pattern, timeout: 1)
        rescue RegexpError => e
          return text_response("Invalid regex pattern: #{e.message}")
        end

        # Validate file_type to prevent injection
        if file_type && !file_type.match?(/\A[a-zA-Z0-9]+\z/)
          return text_response("Invalid file_type: must contain only alphanumeric characters.")
        end

        context_lines = [ [ context_lines.to_i, 0 ].max, 5 ].min
        offset = [ offset.to_i, 0 ].max

        search_path = path ? File.join(root, path) : root

        # Path traversal protection
        unless Dir.exist?(search_path)
          top_dirs = Dir.glob(File.join(root, "*")).select { |f| File.directory?(f) }.map { |f| File.basename(f) }.sort
          return text_response("Path not found: #{path}. Top-level directories: #{top_dirs.first(15).join(', ')}")
        end

        begin
          real_search = File.realpath(search_path)
          real_root = File.realpath(root)
          unless real_search.start_with?(real_root)
            return text_response("Path not allowed: #{path}")
          end
        rescue Errno::ENOENT
          return text_response("Path not found: #{path}")
        end

        # Fetch all results (capped at 200 for safety)
        all_results = if ripgrep_available?
          search_with_ripgrep(search_pattern, search_path, file_type, max_results_cap, root, context_lines, exclude_tests: exclude_tests)
        else
          search_with_ruby(search_pattern, search_path, file_type, max_results_cap, root, exclude_tests: exclude_tests)
        end

        # Filter out definitions for match_type:"call"
        all_results.reject! { |r| r[:content].match?(/\A\s*def\s/) } if match_type == "call"

        if all_results.empty?
          return text_response("No results found for '#{original_pattern}' in #{path || 'app'}.")
        end

        # Smart result limiting:
        # <10 total → show all, 10-100 → show half, >100 → cap at 100
        total = all_results.size
        show_count = if total <= 10 then total
        elsif total <= 100 then (total / 2.0).ceil
        else 100
        end

        # Apply pagination
        paginated = all_results.drop(offset).first(show_count)

        if paginated.empty? && total > 0
          return text_response("No results at offset #{offset}. Total: #{total}. Use `offset:0`.")
        end

        # Build header with total count and pagination info
        showing = offset > 0 ? "#{offset + 1}-#{offset + paginated.size}" : "#{paginated.size}"
        pagination = if offset + paginated.size < total
          "\n_Showing #{showing} of #{total}. Use `offset:#{offset + paginated.size}` for more._"
        elsif total > paginated.size
          "\n_Showing #{showing} of #{total}._"
        else
          ""
        end

        header = "# Search: `#{original_pattern}`\n**#{total} total results**#{" in #{path}" if path}, showing #{showing}\n"

        if group_by_file
          text_response(header + "\n" + format_grouped(paginated) + pagination)
        else
          output = paginated.map { |r| "#{r[:file]}:#{r[:line_number]}: #{r[:content].strip}" }.join("\n")
          text_response("#{header}\n```\n#{output}\n```#{pagination}")
        end
      end

      private_class_method def self.ripgrep_available?
        @rg_available ||= system("which rg > /dev/null 2>&1")
      end

      private_class_method def self.search_with_ripgrep(pattern, search_path, file_type, max_results, root, ctx_lines = 0, exclude_tests: false)
        cmd = [ "rg", "--no-heading", "--line-number", "--sort=path", "--max-count", max_results.to_s ]
        if ctx_lines > 0
          cmd.push("-C", ctx_lines.to_s)
          # Use colon separator for context lines so parse_rg_output handles them correctly
          # (default '-' separator is ambiguous with filenames containing dashes)
          cmd.push("--field-context-separator", ":")
        end

        RailsAiContext.configuration.excluded_paths.each do |p|
          cmd << "--glob=!#{p}"
        end

        # Block sensitive files from search results
        RailsAiContext.configuration.sensitive_patterns.each do |p|
          cmd << "--glob=!#{p}"
        end

        # Exclude test/spec directories if requested
        if exclude_tests
          cmd << "--glob=!test/"
          cmd << "--glob=!spec/"
          cmd << "--glob=!features/"
        end

        if file_type
          cmd.push("--type-add", "custom:*.#{file_type}", "--type", "custom")
        end

        cmd << "--" # Prevent pattern from being parsed as flags
        cmd << pattern
        cmd << search_path

        sensitive = RailsAiContext.configuration.sensitive_patterns
        output, _status = Open3.capture2(*cmd, err: File::NULL)
        parse_rg_output(output, root)
          .reject { |r| sensitive_file?(r[:file], sensitive) }
          .first(max_results)
      rescue => e
        [ { file: "error", line_number: 0, content: e.message } ]
      end

      private_class_method def self.search_with_ruby(pattern, search_path, file_type, max_results, root, exclude_tests: false)
        results = []
        begin
          regex = Regexp.new(pattern, Regexp::IGNORECASE, timeout: 2)
        rescue RegexpError => e
          return [ { file: "error", line_number: 0, content: "Invalid regex: #{e.message}" } ]
        end
        extensions = RailsAiContext.configuration.search_extensions.join(",")
        glob = file_type ? "**/*.#{file_type}" : "**/*.{#{extensions}}"
        excluded = RailsAiContext.configuration.excluded_paths
        sensitive = RailsAiContext.configuration.sensitive_patterns
        test_dirs = %w[test/ spec/ features/]

        Dir.glob(File.join(search_path, glob)).each do |file|
          relative = file.sub("#{root}/", "")
          next if excluded.any? { |ex| relative.start_with?(ex) }
          next if sensitive_file?(relative, sensitive)
          next if exclude_tests && test_dirs.any? { |td| relative.start_with?(td) }

          File.readlines(file).each_with_index do |line, idx|
            if line.match?(regex)
              results << { file: relative, line_number: idx + 1, content: line }
              return results if results.size >= max_results
            end
          end
        rescue => _e
          next # Skip binary/unreadable files
        end

        results
      end

      private_class_method def self.sensitive_file?(relative_path, patterns)
        basename = File.basename(relative_path)
        patterns.any? do |pattern|
          File.fnmatch(pattern, relative_path, File::FNM_DOTMATCH) ||
            File.fnmatch(pattern, basename, File::FNM_DOTMATCH)
        end
      end

      # Group results by file for cleaner output
      private_class_method def self.format_grouped(results)
        grouped = results.group_by { |r| r[:file] }
        lines = []
        grouped.each do |file, matches|
          lines << "## #{file} (#{matches.size} matches)"
          lines << "```"
          matches.each { |r| lines << "#{r[:line_number]}: #{r[:content].strip}" }
          lines << "```"
          lines << ""
        end
        lines.join("\n")
      end

      private_class_method def self.parse_rg_output(output, root)
        output.lines.filter_map do |line|
          next if line.strip == "--" # Skip group separators from -C context output
          match = line.match(/^(.+?):(\d+):(.*)$/)
          next unless match

          {
            file: match[1].sub("#{root}/", ""),
            line_number: match[2].to_i,
            content: match[3]
          }
        end
      end
    end
  end
end
