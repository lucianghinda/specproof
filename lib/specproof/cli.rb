# frozen_string_literal: true

require "json"
require_relative "suggestion_report"

module SpecProof
  # Parses command arguments and dispatches SpecProof commands.
  class CLI
    USAGE = <<~TEXT
      Usage:
        specproof --version
        specproof check [SPECIFICATION.rb ...] [--rbs FILE] [--target TARGET] [--format human|json]
        specproof plan [SPECIFICATION.rb ...] [--rbs FILE] [--target TARGET] [--criterion NAME] [--format human|json]
        specproof suggest SPECIFICATION.rb ... --report COVERAGE.json [--rbs FILE --target TARGET] [--format human|json]
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
      return run_specifications(command, args) if %w[check plan suggest].include?(command)

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
      paths, rbs_paths, targets, criterion, format, option_error, report_path = parse_options(args, kind: kind)
      report_kind = kind == "suggest" ? "suggestions" : kind
      if option_error
        return emit_error(option_error, format, kind: report_kind,
                                                criterion: kind == "plan" ? criterion : nil)
      end
      if paths.empty? && rbs_paths.empty? && targets.empty?
        return emit_error(error("paths_required", "provide specification paths or an RBS selection"), format,
                          kind: report_kind, criterion: kind == "plan" ? criterion : nil)
      end

      with_errors(report_kind, format, criterion: kind == "plan" ? criterion : nil) do
        specifications = with_loader_output(format) do
          if rbs_paths.empty? && targets.empty?
            SpecProof.load(paths)
          else
            SpecProof.load(paths, rbs: rbs_paths, targets: targets)
          end
        end
        case kind
        when "check" then run_check(specifications, format)
        when "plan" then run_plan(specifications, format, criterion)
        else SuggestionReport.execute(specifications: specifications, path: report_path, format: format,
                                      stdout: @stdout)
        end
      end
    end

    def run_check(specifications, format)
      findings = SpecProof.check(specifications)
      if format == "json"
        @stdout.puts(JSON.generate(Report.check(specifications: specifications, findings: findings)))
      else
        if findings.empty?
          @stdout.puts("No specification findings.")
        else
          findings.each { |finding| @stdout.puts(Report.finding(finding)) }
        end
        @stdout.puts(Report.human_scope(specifications))
      end
      findings.empty? ? 0 : 1
    end

    def run_plan(specifications, format, criterion)
      obligations = SpecProof.plan(specifications, criterion: criterion)
      if format == "json"
        @stdout.puts(JSON.generate(Report.plan(specifications: specifications, obligations: obligations,
                                               criterion: criterion)))
      else
        @stdout.puts(Report.human_plan(obligations, criterion: criterion, specifications: specifications))
      end
      0
    rescue InvalidSpecificationError => e
      if format == "json"
        payload = Report.plan(specifications: specifications, obligations: [], criterion: criterion)
        payload[:findings] = e.findings.map { |finding| Report.finding_hash(finding) }
        @stdout.puts(JSON.generate(payload))
      else
        e.findings.each { |finding| @stdout.puts(Report.finding(finding)) }
        @stdout.puts(Report.human_scope(specifications))
      end
      1
    end

    def unknown_command(args, code, message, kind:)
      return emit_error(error(code, message), "json", kind: kind) if json_format_requested?(args)

      @stderr.write(USAGE)
      2
    end

    def with_errors(kind, format, criterion: nil)
      yield
    rescue ConfigurationError => e
      emit_error(error(e.code, e.message, path: e.path, source: e.source), format,
                 kind: kind, criterion: criterion)
    rescue SyntaxError => e
      emit_error(error("syntax_error", e.message, path: e.path), format, kind: kind, criterion: criterion)
    rescue SystemCallError, IOError => e
      emit_error(error("io_error", e.message), format, kind: kind, criterion: criterion)
    rescue StandardError => e
      emit_error(error("specification_error", e.message), format, kind: kind, criterion: criterion)
    end

    def parse_options(args, kind:)
      options = { format: "human", criterion: "input-basics-v1", criterion_seen: false,
                  paths: [], rbs_paths: [], targets: [], report_paths: [], parse_error: nil }
      while (argument = args.shift)
        parse_error = parse_option(argument, args, options, kind)
        options[:parse_error] ||= parse_error
      end
      if kind == "suggest" && options[:report_paths].empty?
        options[:parse_error] ||= error("missing_coverage_report", "suggest requires one --report COVERAGE.json")
      end
      [options[:paths], options[:rbs_paths], options[:targets], options[:criterion], options[:format],
       options[:parse_error], options[:report_paths].first]
    end

    def parse_option(argument, args, options, kind)
      case argument
      when "--format" then parse_format_option(args, options)
      when "--criterion" then parse_criterion_option(args, options, kind)
      when "--report" then SuggestionReport.parse_report_option(args: args, options: options, kind: kind)
      when "--rbs", "--target" then parse_selection_option(argument, args, options)
      else parse_path_option(argument, options)
      end
    end

    def parse_format_option(args, options)
      value = args.shift
      if %w[human json].include?(value)
        options[:format] = value
        nil
      else
        args.unshift(value) if value
        error("invalid_format", "--format requires human or json")
      end
    end

    def parse_criterion_option(args, options, kind)
      value, parse_error = option_value("--criterion", args)
      return parse_error unless value
      return error("unsupported_option", "--criterion is available only for plan") unless kind == "plan"
      return error("duplicate_criterion", "specify --criterion only once") if options[:criterion_seen]

      options[:criterion] = value
      options[:criterion_seen] = true
      nil
    end

    def parse_selection_option(argument, args, options)
      value, parse_error = option_value(argument, args)
      return parse_error unless value

      options.fetch(argument == "--rbs" ? :rbs_paths : :targets) << value
      nil
    end

    def option_value(argument, args)
      value = args.shift
      if value.nil? || value.empty? || value.start_with?("-")
        args.unshift(value) if value
        [nil, error("missing_option_value", "#{argument} requires a value")]
      else
        [value, nil]
      end
    end

    def parse_path_option(argument, options)
      if argument.start_with?("-")
        error("unsupported_option", "unsupported option #{argument.inspect}")
      else
        options[:paths] << argument
        nil
      end
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

    def emit_error(details, format, kind: "error", criterion: nil)
      if format == "json"
        payload = Report.envelope(kind: kind, errors: [details])
        payload[:criterion] = criterion if criterion
        @stdout.puts(JSON.generate(payload))
      else
        @stderr.puts("#{details[:code]}: #{details[:message]}")
      end
      2
    end
  end
end
