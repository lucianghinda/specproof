# frozen_string_literal: true

require "json"

module SpecProof
  # Renders deterministic machine and human reports for unexecuted suggestions.
  module SuggestionReport
    MAX_REPORT_BYTES = 32 * 1024 * 1024

    module_function

    def from_file(specifications:, path:)
      SpecProof.suggest(specifications, report: read_report(path))
    end

    def findings(specifications:, error:, format:, criterion: Suggestions::CRITERION)
      if format == "json"
        JSON.generate(
          Report.envelope(kind: "suggestions").merge(
            criterion: criterion,
            strategy: strategy_for(criterion),
            findings: error.findings.map { |finding| Report.finding_hash(finding) }
          )
        )
      else
        rows = error.findings.map { |finding| Report.finding(finding) }
        rows << Report.human_scope(specifications)
        rows.join("\n")
      end
    end

    def render(result, format:)
      format == "json" ? JSON.generate(document(result)) : human(result)
    end

    def execute(specifications:, path:, format:, stdout:)
      criterion = nil
      report = read_report(path)
      criterion = criterion_from(report)
      result = SpecProof.suggest(specifications, report: report)
      stdout.puts(render(result, format: format))
      0
    rescue InvalidSpecificationError => e
      stdout.puts(findings(specifications: specifications, error: e, format: format,
                           criterion: criterion || Suggestions::CRITERION))
      1
    end

    def parse_report_option(args:, options:, kind:)
      value = args.shift
      if value.nil? || value.empty? || value.start_with?("-")
        args.unshift(value) if value
        return { code: "missing_option_value", message: "--report requires a value" }
      end
      return { code: "unsupported_option", message: "--report is available only for suggest" } unless kind == "suggest"
      unless options.fetch(:report_paths).empty?
        return { code: "duplicate_coverage_report", message: "specify --report only once" }
      end

      options.fetch(:report_paths) << value
      nil
    end

    def document(result)
      covered_ids = result.suggestions.flat_map(&:covers).uniq
      Report.envelope(kind: "suggestions").merge(
        criterion: result.criterion,
        strategy: result.strategy,
        assignment_scope: "combination_group",
        minimality: "not_guaranteed",
        contract_digest: result.contract_digest,
        source_run_id: result.source_run_id,
        source_tests_passed: result.source_tests_passed,
        source_scope: result.source_scope,
        missing_obligation_count: result.missing_count,
        covered_obligation_count: covered_ids.length,
        suggestion_count: result.suggestions.length,
        suggestions: result.suggestions.map { |suggestion| suggestion_hash(suggestion) }
      )
    end

    def human(result)
      lines = ["Source run: #{result.source_run_id}",
               "Source tests: #{result.source_tests_passed ? "passed" : "failed"}",
               "Criterion: #{result.criterion}; strategy: #{result.strategy}",
               "Source arguments: #{result.source_scope.fetch("arguments").inspect}",
               "Source scope: #{human_scope(result.source_scope)}",
               "Missing pair obligations: #{result.missing_count}",
               "Suggestions: #{result.suggestions.length} (minimum not guaranteed)"]
      result.suggestions.each_with_index do |suggestion, index|
        assignments = suggestion.inputs.map do |name, value|
          "#{name}=#{Report.human_value(value)}"
        end.join(", ")
        lines << "#{index + 1}. #{suggestion.target}: #{assignments}"
        lines << "   Covers: #{suggestion.covers.join(", ")}"
        lines << "   Unassigned inputs: #{suggestion.unassigned_inputs.join(", ")}" if suggestion.unassigned_inputs.any?
      end
      lines << "These suggestions have not been executed."
      lines << "No expected results are provided. Supply unassigned inputs before calling the target."
      lines.join("\n")
    end

    def suggestion_hash(suggestion)
      {
        id: suggestion.id,
        target: suggestion.target,
        inputs: suggestion.inputs.to_h { |name, value| [name.to_s, Report.value(value)] },
        covers: suggestion.covers,
        unassigned_inputs: suggestion.unassigned_inputs.map(&:to_s),
        sources: suggestion.sources.map { |source| Report.source(source) }
      }
    end
    private_class_method :suggestion_hash

    def human_scope(scope)
      pieces = []
      filter = scope["filter"]
      exclude = scope["exclude"]
      pieces << "filter #{filter.inspect}" if filter
      pieces << "exclude #{exclude.inspect}" if exclude
      input_scope = scope["input_scope"] || []
      input_scope.each do |item|
        group = item["combination_group"]
        next unless group

        pieces << "#{item.fetch("target")} combinations #{group.fetch("inputs").join(", ")}"
      end
      pieces.empty? ? "all recorded targets" : pieces.join("; ")
    end
    private_class_method :human_scope

    def read_report(path)
      content = File.open(path, "rb") { |file| file.read(MAX_REPORT_BYTES + 1) } || ""
      if content.bytesize > MAX_REPORT_BYTES
        raise ConfigurationError.new("coverage report exceeds the 32 MiB limit",
                                     code: "suggestion_limit_exceeded", path: path)
      end

      JSON.parse(content)
    rescue JSON::ParserError => e
      raise ConfigurationError.new("coverage report is not valid JSON: #{e.message}",
                                   code: "invalid_coverage_report", path: path)
    end
    private_class_method :read_report

    def criterion_from(report)
      return Suggestions::PARTITION_CRITERION if report.is_a?(Hash) &&
                                                 report["criterion"] == Suggestions::PARTITION_CRITERION

      Suggestions::CRITERION
    end
    private_class_method :criterion_from

    def strategy_for(criterion)
      criterion == Suggestions::PARTITION_CRITERION ? Suggestions::PARTITION_STRATEGY : Suggestions::STRATEGY
    end
    private_class_method :strategy_for
  end
end
