# frozen_string_literal: true

require "json"

module SpecProof
  # Parses command arguments and renders check or plan results.
  class CLI
    USAGE = <<~TEXT
      Usage:
        specproof --version
        specproof check SPECIFICATION.rb [SPECIFICATION.rb ...] [--format human|json]
        specproof plan SPECIFICATION.rb [SPECIFICATION.rb ...] [--format human|json]
        specproof skills export --to DIRECTORY [--format human|json]
    TEXT

    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(argv)
      args = argv.dup
      if [["--version"], ["-v"]].include?(args)
        @stdout.puts("SpecProof #{VERSION}")
        return 0
      end
      if args.empty? || args == ["--help"] || args == ["-h"] || args == ["help"]
        @stdout.write(USAGE)
        return 0
      end

      command = args.shift
      return run_skills(args) if command == "skills"
      return run_specifications(command, args) if %w[check plan].include?(command)

      unknown_command(args, "unknown_command", "unsupported command #{command.inspect}", kind: "error")
    end

    private

    def run_skills(args)
      unless args.shift == "export"
        return unknown_command(args, "unknown_skills_command", "expected skills export", kind: "skills_export")
      end

      destination, format, option_error = parse_skill_options(args)
      return emit_error(option_error, format, kind: "skills_export") if option_error

      with_errors("skills_export", format) do
        result = Skills.export(to: destination)
        if format == "json"
          @stdout.puts(JSON.generate(Report.envelope(kind: "skills_export").merge(result)))
        elsif result.fetch(:exported).empty?
          @stdout.puts("Skills already match the export at #{result.fetch(:destination)}.")
        else
          @stdout.puts("Exported #{result.fetch(:exported).length} skill files to #{result.fetch(:destination)}.")
        end
        0
      end
    end

    def run_specifications(kind, args)
      paths, format, option_error = parse_options(args)
      return emit_error(option_error, format, kind: kind) if option_error
      if paths.empty?
        return emit_error(error("paths_required", "provide at least one specification path"), format,
                          kind: kind)
      end

      with_errors(kind, format) do
        specifications = with_loader_output(format) { SpecProof.load(paths) }
        kind == "check" ? run_check(specifications, format) : run_plan(specifications, format)
      end
    end

    def run_check(specifications, format)
      findings = SpecProof.check(specifications)
      if format == "json"
        @stdout.puts(JSON.generate(Report.check(specifications: specifications, findings: findings)))
      elsif findings.empty?
        @stdout.puts("No specification findings.")
      else
        findings.each { |finding| @stdout.puts(Report.finding(finding)) }
      end
      findings.empty? ? 0 : 1
    end

    def run_plan(specifications, format)
      obligations = SpecProof.plan(specifications)
      if format == "json"
        @stdout.puts(JSON.generate(Report.plan(specifications: specifications, obligations: obligations)))
      else
        @stdout.puts(Report.human_plan(obligations))
      end
      0
    rescue InvalidSpecificationError => e
      if format == "json"
        payload = Report.plan(specifications: specifications, obligations: [])
        payload[:findings] = e.findings.map { |finding| Report.finding_hash(finding) }
        @stdout.puts(JSON.generate(payload))
      else
        e.findings.each { |finding| @stdout.puts(Report.finding(finding)) }
      end
      1
    end

    def unknown_command(args, code, message, kind:)
      return emit_error(error(code, message), "json", kind: kind) if json_format_requested?(args)

      @stderr.write(USAGE)
      2
    end

    def with_errors(kind, format)
      yield
    rescue ConfigurationError => e
      emit_error(error(e.code, e.message, path: e.path, source: e.source), format,
                 kind: kind)
    rescue SyntaxError => e
      emit_error(error("syntax_error", e.message, path: e.path), format, kind: kind)
    rescue SystemCallError, IOError => e
      emit_error(error("io_error", e.message), format, kind: kind)
    rescue StandardError => e
      emit_error(error("specification_error", e.message), format, kind: kind)
    end

    def parse_options(args)
      format = "human"
      paths = []
      parse_error = nil
      while (arg = args.shift)
        if arg == "--format"
          value = args.shift
          valid_formats = %w[human json]
          if valid_formats.include?(value)
            format = value
          else
            parse_error ||= error("invalid_format", "--format requires human or json")
          end
        elsif arg.start_with?("-")
          parse_error ||= error("unsupported_option", "unsupported option #{arg.inspect}")
        else
          paths << arg
        end
      end
      [paths, format, parse_error]
    end

    def json_format_requested?(args)
      index = args.index("--format")
      index && args[index + 1] == "json"
    end

    def parse_skill_options(args)
      destination = nil
      format = "human"
      parse_error = nil
      destination_seen = false

      while (arg = args.shift)
        case arg
        when "--to"
          value = args.shift
          if destination_seen
            parse_error ||= error("duplicate_destination", "specify --to only once")
          elsif value.nil? || value.start_with?("--")
            args.unshift(value) if value
            parse_error ||= error("missing_skills_destination", "--to requires a destination")
          else
            destination = value
            destination_seen = true
          end
        when "--format"
          value = args.shift
          if %w[human json].include?(value)
            format = value
          else
            parse_error ||= error("invalid_format", "--format requires human or json")
          end
        else
          parse_error ||= error("unsupported_option", "unsupported skill export argument #{arg.inspect}")
        end
      end

      unless destination || parse_error
        parse_error = error("missing_skills_destination", "provide an explicit destination with --to")
      end
      [destination, format, parse_error]
    end

    def with_loader_output(format)
      return yield unless format == "json"

      original = $stdout
      $stdout = @stderr
      yield
    ensure
      $stdout = original if format == "json"
    end

    def error(code, message, path: nil, source: nil)
      result = { code: code.to_s, message: message.to_s }
      result[:path] = path if path
      result[:source] = Report.source(source) if source
      result
    end

    def emit_error(details, format, kind: "error")
      if format == "json"
        @stdout.puts(JSON.generate(Report.envelope(kind: kind, errors: [details])))
      else
        @stderr.puts("#{details[:code]}: #{details[:message]}")
      end
      2
    end
  end
end
