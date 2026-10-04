# frozen_string_literal: true

module SpecProof
  # Supplies stable validation failures to the report reader.
  module CoverageReportErrors
    private

    def unsupported!(message) = raise ConfigurationError.new(message, code: "unsupported_coverage_report")

    def incomplete!(message) = raise ConfigurationError.new(message, code: "incomplete_coverage_report")

    def mismatch!(message) = raise ConfigurationError.new(message, code: "coverage_contract_mismatch")

    def invalid!(message) = raise ConfigurationError.new(message, code: "invalid_coverage_report")
  end

  # Checks and owns the JSON-shaped data preserved by a validated report.
  module CoverageReportJSON
    private

    def deep_copy_freeze(value)
      case value
      when Hash
        value.to_h { |key, item| [key.dup.freeze, deep_copy_freeze(item)] }.freeze
      when Array
        value.map { |item| deep_copy_freeze(item) }.freeze
      when String
        value.dup.freeze
      else
        value.freeze
      end
    end

    def json_object?(value)
      value.is_a?(Hash) && value.keys.all?(String) &&
        value.values.all? { |item| json_value?(item) }
    end

    def json_value?(value)
      case value
      when Hash then value.keys.all?(String) && value.values.all? { |item| json_value?(item) }
      when Array then value.all? { |item| json_value?(item) }
      when String, Integer, TrueClass, FalseClass, NilClass then true
      when Float then value.finite?
      else false
      end
    end
  end

  # Validates bounded runtime evidence against a freshly planned pairwise contract.
  class CoverageReport
    include CoverageReportErrors
    include CoverageReportJSON

    SCHEMA_VERSION = 1
    KIND = "coverage"
    CRITERION = "pairwise-finite-v1"
    PARTITION_CRITERION = "pairwise-partitions-v1"
    REQUIRED_SCOPE = {
      "window" => "minitest_run",
      "method_identity" => "direct_owner_definition",
      "input_semantics" => "effective_bound_values",
      "argument_presence" => "not_observed"
    }.freeze
    REQUIRED_FIELDS = %w[
      schema_version kind errors contract_digest criterion run_id scope evidence_mode replay
      obligations missing exercised exercised_count obligation_count missing_count unknown_count
      not_observed_count completion_percent completion integrity tests_passed incomplete_reasons
    ].freeze

    attr_reader :contract_digest, :missing_ids, :run_id, :tests_passed, :scope, :scope_snapshot, :criterion

    def initialize(report, specifications:, obligations:, criterion: CRITERION)
      @specifications = specifications
      @obligations = obligations
      @criterion = criterion.is_a?(String) ? criterion.dup.freeze : criterion
      validate_document!(report)
      @contract_digest, @run_id = report.values_at("contract_digest", "run_id").map { |value| value.dup.freeze }
      @scope = @scope_snapshot = deep_copy_freeze(report.fetch("scope"))
      @tests_passed = report.fetch("tests_passed")
      @missing_ids = report.fetch("missing").map { |row| row.fetch("id").dup.freeze }.freeze
      freeze
    end

    private

    def validate_document!(report)
      invalid!("coverage report must be a JSON object") unless report.is_a?(Hash) && report.keys.all?(String)
      missing_fields = REQUIRED_FIELDS - report.keys
      invalid!("coverage report is missing required fields: #{missing_fields.join(", ")}") unless missing_fields.empty?
      validate_identity!(report)
      validate_completion!(report)
      validate_rows!(report)
      validate_projections!(report)
      validate_counts!(report)
      validate_completion_percent!(report)
      validate_scope!(report.fetch("scope"))
    end

    def validate_identity!(report)
      unless report["schema_version"].is_a?(Integer) && report["schema_version"] == SCHEMA_VERSION &&
             report["kind"] == KIND && [CRITERION, PARTITION_CRITERION].include?(criterion) &&
             report["criterion"] == criterion
        unsupported!("coverage report schema, kind, or criterion is unsupported")
      end
      unless report["run_id"].is_a?(String) && !report["run_id"].empty?
        invalid!("coverage report run_id must be a non-empty string")
      end
      return if report["contract_digest"] == Report.digest(@specifications)

      mismatch!("coverage report contract digest does not match specifications")
    end

    def validate_completion!(report)
      invalid!("coverage report completion must be a string") unless report["completion"].is_a?(String)
      incomplete!("coverage report is not complete") unless report["completion"] == "completed"
      invalid!("coverage report integrity must be boolean") unless [true, false].include?(report["integrity"])
      incomplete!("coverage report integrity is false") unless report["integrity"]
      invalid!("coverage report errors must be an array") unless report["errors"].is_a?(Array)
      incomplete!("coverage report contains errors") unless report["errors"].empty?
      invalid!("coverage report incomplete_reasons must be an array of strings") unless
        report["incomplete_reasons"].is_a?(Array) && report["incomplete_reasons"].all?(String)
      incomplete!("coverage report contains incomplete reasons") unless report["incomplete_reasons"].empty?
      invalid!("coverage report evidence_mode must be a string") unless report["evidence_mode"].is_a?(String)
      invalid!("coverage report replay must be boolean") unless [true, false].include?(report["replay"])
      unless report["evidence_mode"] == "obligation_hits" && report["replay"] == false
        incomplete!("coverage report does not contain direct obligation-hit evidence")
      end
      unless report["tests_passed"].equal?(true) || report["tests_passed"].equal?(false)
        invalid!("coverage report tests_passed must be boolean")
      end
      invalid!("coverage report unknown_count must be an integer") unless report["unknown_count"].is_a?(Integer)
      return if report["unknown_count"].zero?

      incomplete!("coverage report contains unknown obligations")
    end

    def validate_scope!(scope)
      invalid!("coverage report scope must be a JSON object") unless json_object?(scope)
      REQUIRED_SCOPE.each do |key, value|
        mismatch!("coverage report scope #{key} does not match the adapter") unless scope[key] == value
      end
      unless scope.key?("arguments") && scope["arguments"].is_a?(Array) && scope["arguments"].all?(String) &&
             scope.key?("filter") && [String, NilClass].include?(scope["filter"].class) &&
             scope.key?("exclude") && [String, NilClass].include?(scope["exclude"].class)
        invalid!("coverage report scope arguments, filter, or exclude has an invalid type")
      end
      expected_targets = @specifications.map(&:target).sort
      unless scope["targets"].is_a?(Array) && scope["targets"].all?(String)
        invalid!("coverage report scope targets must be strings")
      end
      mismatch!("coverage report targets do not match specifications") unless scope["targets"].sort == expected_targets
      expected_scope = Report.input_scope(@specifications)
      actual_scope = scope["input_scope"]
      invalid!("coverage report input_scope must be an array") unless actual_scope.is_a?(Array)
      unless scope_projection(actual_scope) == scope_projection(expected_scope[:input_scope])
        mismatch!("coverage report analyzed input scope does not match specifications")
      end
      unless scope["completeness_scope"] == "analyzed_inputs"
        mismatch!("coverage report completeness scope does not match specifications")
      end
    rescue NoMethodError, ArgumentError, TypeError
      mismatch!("coverage report scope does not match specifications")
    end

    def validate_rows!(report)
      rows = report["obligations"]
      invalid!("coverage report obligations must be an array") unless rows.is_a?(Array)
      mismatch!("coverage report obligation denominator does not match plan") unless rows.length == @obligations.length

      expected = @obligations.to_h { |obligation| [obligation.id, obligation] }
      mismatch!("planned obligation IDs are not unique") unless expected.length == @obligations.length
      seen = {}
      rows.each do |row|
        invalid!("coverage obligation row must be an object") unless row.is_a?(Hash) && row.keys.all?(String)
        id = row["id"]
        invalid!("coverage obligation ID must be a string") unless id.is_a?(String) && !id.empty?
        invalid!("coverage obligation rows contain duplicate IDs") if seen[id]
        obligation = expected[id]
        mismatch!("coverage obligation IDs do not match plan") unless obligation
        validate_row!(row, obligation)
        seen[id] = true
      end
      mismatch!("coverage obligation IDs do not match plan") unless seen.length == expected.length
    end

    def validate_row!(row, obligation)
      invalid!("coverage obligation hits must be an integer") unless row["hits"].is_a?(Integer)
      invalid!("coverage obligation target must be a string") unless row["target"].is_a?(String)
      unless row["inputs"].is_a?(Hash) && row["inputs"].keys.all?(String)
        invalid!("coverage obligation inputs must be an object")
      end
      row["inputs"].each_value do |typed|
        invalid!("coverage obligation input value is malformed") unless valid_typed_value?(typed)
      end
      unless row["status"].is_a?(String) && %w[exercised not_observed unknown].include?(row["status"])
        invalid!("coverage obligation status is invalid")
      end
      incomplete!("coverage report contains unknown obligations") if row["status"] == "unknown"
      unless row["target"].eql?(obligation.target) && row["inputs"].eql?(typed_inputs(obligation.inputs))
        mismatch!("coverage obligation contents do not match plan")
      end
      valid_hits = (row["status"] == "exercised" && row["hits"].positive?) ||
                   (row["status"] == "not_observed" && row["hits"].zero?)
      invalid!("coverage obligation status and hits disagree") unless valid_hits
    end

    def validate_projections!(report)
      rows = report.fetch("obligations")
      { "missing" => "not_observed", "exercised" => "exercised" }.each do |field, status|
        projection = report[field]
        invalid!("coverage report #{field} projection must be an array") unless projection.is_a?(Array)
        expected = rows.select { |row| row.fetch("status") == status }
        unless projection.length == expected.length
          invalid!("coverage report #{field} projection has an invalid row count")
        end
        projection.each { |item| validate_projection_row!(item, field) }
        invalid!("coverage report #{field} projection disagrees with obligations") unless
          projection_signature(projection).eql?(projection_signature(expected))
      end
    end

    def validate_projection_row!(row, field)
      invalid!("coverage report #{field} projection contains a malformed row") unless projection_row?(row)
    end

    def projection_row?(row)
      return false unless row.is_a?(Hash) && row.keys.all?(String)

      %w[id target status].all? { |key| row[key].is_a?(String) } &&
        row["inputs"].is_a?(Hash) && row["inputs"].keys.all?(String) &&
        row["inputs"].values.all? { |typed| valid_typed_value?(typed) } && row["hits"].is_a?(Integer)
    end

    def valid_typed_value?(typed)
      return false unless typed.is_a?(Hash) && typed.keys.all?(String) && typed["kind"].is_a?(String)

      case typed["kind"]
      when "nil" then typed.keys.sort == %w[kind value] && typed["value"].nil?
      when "boolean" then typed.keys.sort == %w[kind value] && [true, false].include?(typed["value"])
      when "integer", "symbol", "string"
        typed.keys.sort == %w[kind value] && typed["value"].is_a?(String)
      when "partition"
        typed.keys.sort == %w[kind lower name upper] && typed["name"].is_a?(String) &&
          canonical_integer_string?(typed["lower"]) && canonical_integer_string?(typed["upper"]) &&
          Integer(typed["lower"], 10) <= Integer(typed["upper"], 10)
      else false
      end
    rescue ArgumentError
      false
    end

    def canonical_integer_string?(value)
      value.is_a?(String) && value.match?(/\A-?(?:0|[1-9]\d*)\z/) && Integer(value, 10).to_s == value
    end

    def validate_counts!(report)
      values = %w[exercised_count obligation_count missing_count unknown_count not_observed_count]
      invalid!("coverage report counts must be integers") unless values.all? { |key| report[key].is_a?(Integer) }
      exercised = report.fetch("obligations").count { |row| row.fetch("status") == "exercised" }
      missing = report.fetch("obligations").count { |row| row.fetch("status") == "not_observed" }
      expected = { "exercised_count" => exercised, "obligation_count" => @obligations.length,
                   "missing_count" => missing, "unknown_count" => 0, "not_observed_count" => missing }
      invalid!("coverage report counters disagree with obligation rows") unless values.to_h do |key|
        [key, report[key]]
      end == expected
    end

    def validate_completion_percent!(report)
      value = report["completion_percent"]
      return if value.nil? && report["exercised_count"].zero?

      invalid!("coverage report cannot give a percentage for an empty denominator") if report["obligation_count"].zero?
      unless value.is_a?(Numeric) && !value.is_a?(Complex)
        invalid!("coverage report completion_percent must be numeric or null")
      end

      expected = ((report.fetch("exercised_count") * 100.0) / report.fetch("obligation_count")).round(2)
      invalid!("coverage report completion_percent disagrees with counters") unless value == expected
    end

    def scope_projection(scope)
      return nil unless scope.is_a?(Array)

      entries = scope.map { |item| scope_entry_projection(item) }
      entries.sort
    rescue ArgumentError, TypeError
      invalid!("coverage report input scope is malformed")
    end

    def scope_entry_projection(item)
      invalid!("coverage report input scope is malformed") unless item.is_a?(Hash)

      target = item["target"] || item[:target]
      names = item["analyzed_inputs"] || item[:analyzed_inputs]
      excluded = item["excluded_inputs"] || item[:excluded_inputs]
      group = item["combination_group"] || item[:combination_group]
      unless target.is_a?(String) && names.is_a?(Array) && names.all?(String) && excluded.is_a?(Array)
        invalid!("coverage report input scope is malformed")
      end
      exclusion_names = excluded.map { |entry| exclusion_name(entry) }
      group_inputs = group && group_inputs_for_scope(group)
      [target, names.sort, exclusion_names.sort, group_inputs&.sort]
    end

    def exclusion_name(entry)
      name = entry.is_a?(Hash) ? entry["name"] || entry[:name] : nil
      invalid!("coverage report excluded input scope is malformed") unless name.is_a?(String)

      name
    end

    def group_inputs_for_scope(group)
      inputs = group.is_a?(Hash) ? group["inputs"] || group[:inputs] : nil
      invalid!("coverage report combination group is malformed") unless inputs.is_a?(Array) && inputs.all?(String)

      inputs
    end

    def projection_signature(rows)
      signatures = rows.map do |row|
        [row["id"], row["target"], row["inputs"], row["status"], row["hits"]]
      end
      signatures.sort_by { |id,| id.to_s }
    end

    def typed_inputs(inputs)
      inputs.to_h do |name, value|
        typed = Report.value(value)
        [name.to_s, typed.to_h { |key, item| [key.to_s, item] }]
      end
    end
  end
end
