# frozen_string_literal: true

require "test_helper"
require "json"
require_relative "../lib/specproof/coverage_report"

class CoverageReportTest < Minitest::Test
  CRITERION = "pairwise-finite-v1"

  def setup
    @specifications = SpecProof.load([fixture("pairwise_constrained.rb")])
    @obligations = SpecProof.plan(@specifications, criterion: CRITERION)
  end

  def test_accepts_a_json_round_trip_of_the_real_coverage_and_adapter_envelopes
    document = coverage_document
    validator = validate(document)

    assert_equal document.fetch("missing").map { |row| row.fetch("id") }, validator.missing_ids
    assert_equal "run-123", validator.run_id
    assert_equal true, validator.tests_passed
    assert validator.scope.frozen?
    assert validator.scope_snapshot.frozen?
  end

  def test_rejects_a_tampered_row_even_when_its_id_is_unchanged
    document = coverage_document
    row = document.fetch("obligations").first
    input_name = row.fetch("inputs").keys.first
    row.fetch("inputs")[input_name] = { "kind" => "boolean", "value" => !row.dig("inputs", input_name, "value") }

    assert_error("coverage_contract_mismatch") { validate(document) }
  end

  def test_rejects_float_typed_values_for_integer_pairs_in_rows_and_projections
    specifications = integer_pair_specifications
    obligations = SpecProof.plan(specifications, criterion: CRITERION)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    report = adapter_document(specifications: specifications, projection: coverage.to_report)

    tampered_rows = JSON.parse(JSON.generate(report))
    tamper_integer_encodings(tampered_rows.fetch("obligations"))
    tamper_integer_encodings(tampered_rows.fetch("missing"))
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::CoverageReport.new(tampered_rows, specifications: specifications, obligations: obligations)
    end
    assert_equal "invalid_coverage_report", error.code

    tampered_projection = JSON.parse(JSON.generate(report))
    tamper_integer_encodings(tampered_projection.fetch("missing"))
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::CoverageReport.new(tampered_projection, specifications: specifications, obligations: obligations)
    end
    assert_equal "invalid_coverage_report", error.code
  end

  def test_rejects_inconsistent_projections_and_counters
    document = coverage_document
    document["missing_count"] += 1

    assert_error("invalid_coverage_report") { validate(document) }
  end

  def test_rejects_float_hits_and_wrong_cardinality_in_projection_rows
    document = coverage_document
    document.fetch("exercised").first["hits"] = 1.0
    assert_error("invalid_coverage_report") { validate(document) }

    document = coverage_document
    document.fetch("missing").pop
    assert_error("invalid_coverage_report") { validate(document) }
  end

  def test_rejects_non_hash_running_and_incomplete_reports
    assert_error("invalid_coverage_report") { validate([]) }
    assert_error("incomplete_coverage_report") { validate(coverage_document.merge("completion" => "running")) }
    assert_error("incomplete_coverage_report") do
      validate(coverage_document.merge("completion" => "incomplete"))
    end
  end

  def test_rejects_schema_kind_criterion_and_contract_mismatches
    assert_error("unsupported_coverage_report") { validate(coverage_document.merge("criterion" => "future")) }
    assert_error("unsupported_coverage_report") { validate(coverage_document.merge("schema_version" => 2)) }
    assert_error("unsupported_coverage_report") { validate(coverage_document.merge("kind" => "plan")) }
    assert_error("coverage_contract_mismatch") do
      validate(coverage_document.merge("contract_digest" => "stale"))
    end
  end

  def test_accepts_a_failed_test_result_and_preserves_false
    validator = validate(coverage_document.merge("tests_passed" => false))

    assert_equal false, validator.tests_passed
  end

  def test_accepts_filtered_scope_and_owns_frozen_scope_snapshot
    document = coverage_document
    document.fetch("scope")["arguments"] = [String.new("--name"), String.new("test_pairwise")]
    document.fetch("scope")["filter"] = "test_pairwise"
    document.fetch("scope")["targets"] = ["ConstrainedPairwise#call"]
    validator = validate(document)

    assert_equal ["--name", "test_pairwise"], validator.scope.fetch("arguments")
    assert_raises(FrozenError) { validator.scope.fetch("arguments").first.replace("changed") }
  end

  def test_snapshot_owns_scope_strings_after_validation
    document = coverage_document
    document.fetch("scope")["arguments"] = [String.new("--name"), String.new("test_pairwise")]
    validator = validate(document)

    document.fetch("scope").fetch("arguments").first.replace("--exclude")
    document.fetch("scope").fetch("input_scope").first.fetch("target").replace("Changed#target")

    assert_equal "--name", validator.scope.fetch("arguments").first
    assert_equal "ConstrainedPairwise#call", validator.scope.dig("input_scope", 0, "target")
  end

  def test_rejects_target_input_group_or_exclusion_scope_changes
    [
      ->(scope) { scope["targets"] = ["Other#call"] },
      ->(scope) { scope.fetch("input_scope").first["analyzed_inputs"] = ["a"] },
      ->(scope) { scope.fetch("input_scope").first["combination_group"]["inputs"] = ["a"] },
      ->(scope) { scope.fetch("input_scope").first["excluded_inputs"] = [{ "name" => "c", "reason" => "ignored" }] }
    ].each do |change|
      document = coverage_document
      change.call(document.fetch("scope"))
      assert_error("coverage_contract_mismatch") { validate(document) }
    end
  end

  def test_accepts_reordered_rows_and_scope_names
    document = coverage_document
    document["obligations"].reverse!
    document["missing"].reverse!
    document["exercised"].reverse!
    document.fetch("scope").fetch("input_scope").first["analyzed_inputs"].reverse!
    document.fetch("scope").fetch("input_scope").first.fetch("combination_group")["inputs"].reverse!

    assert_instance_of SpecProof::CoverageReport, validate(document)
  end

  def test_rejects_non_boolean_test_result_and_bad_runtime_scope_fields
    assert_error("invalid_coverage_report") { validate(coverage_document.merge("tests_passed" => nil)) }
    document = coverage_document
    document.fetch("scope")["arguments"] = ["--name", nil]
    assert_error("invalid_coverage_report") { validate(document) }
  end

  def test_rejects_missing_required_envelope_and_scope_fields
    report = coverage_document
    report.delete("incomplete_reasons")
    assert_error("invalid_coverage_report") { validate(report) }

    report = coverage_document
    report.fetch("scope").delete("exclude")
    assert_error("invalid_coverage_report") { validate(report) }

    report = coverage_document
    report.fetch("scope").fetch("input_scope").first.delete("excluded_inputs")
    assert_error("invalid_coverage_report") { validate(report) }
  end

  def test_rejects_incomplete_reasons_unknown_counts_and_inaccurate_percent
    report = coverage_document
    report["incomplete_reasons"] = ["collection stopped"]
    assert_error("incomplete_coverage_report") { validate(report) }

    report = coverage_document
    report["unknown_count"] = 1
    assert_error("incomplete_coverage_report") { validate(report) }

    report = coverage_document
    report["completion_percent"] = nil
    assert_error("invalid_coverage_report") { validate(report) }
  end

  def test_rejects_distinct_row_identity_shape_and_count_tampering
    cases = [
      ["duplicate ID", "invalid_coverage_report", lambda { |report|
        report.fetch("obligations")[1]["id"] = report.fetch("obligations").first.fetch("id")
      }],
      ["missing row", "coverage_contract_mismatch", ->(report) { report.fetch("obligations").pop }],
      ["extra row", "coverage_contract_mismatch", lambda { |report|
        report.fetch("obligations") << JSON.parse(JSON.generate(report.fetch("obligations").first))
      }],
      ["forged ID", "coverage_contract_mismatch", lambda { |report|
        report.fetch("obligations").first["id"] = "0" * 64
      }],
      ["changed typed encoding", "coverage_contract_mismatch", lambda { |report|
        row = report.fetch("obligations").first
        typed = row.fetch("inputs").values.first
        typed["kind"] = "symbol"
        typed["value"] = "false"
      }],
      ["mixed typed keys", "invalid_coverage_report", lambda { |report|
        typed = report.fetch("obligations").first.fetch("inputs").values.first
        typed[:kind] = typed.delete("kind")
      }],
      ["Boolean hits", "invalid_coverage_report", ->(report) { report.fetch("obligations").first["hits"] = true }],
      ["negative hits", "invalid_coverage_report", ->(report) { report.fetch("obligations").first["hits"] = -1 }],
      ["float hits", "invalid_coverage_report", ->(report) { report.fetch("obligations").first["hits"] = 1.0 }],
      ["invalid status", "invalid_coverage_report",
       ->(report) { report.fetch("obligations").first["status"] = "observed" }]
    ]

    assert_mutations(cases)
  end

  def test_rejects_incomplete_evidence_flags_and_strict_counter_mutations
    cases = [
      ["false integrity", "incomplete_coverage_report", ->(report) { report["integrity"] = false }],
      ["nonempty errors", "incomplete_coverage_report", ->(report) { report["errors"] = [{ "code" => "failed" }] }],
      ["replay evidence", "incomplete_coverage_report", ->(report) { report["replay"] = true }],
      ["wrong evidence mode", "incomplete_coverage_report", ->(report) { report["evidence_mode"] = "trace" }],
      ["Boolean counter", "invalid_coverage_report", ->(report) { report["missing_count"] = true }],
      ["changed percentage", "invalid_coverage_report", ->(report) { report["completion_percent"] = 50.0 }]
    ]

    assert_mutations(cases)
  end

  def test_rejects_missing_required_scope_arguments_without_leaking_key_errors
    report = coverage_document
    report.fetch("scope").delete("arguments")

    assert_error("invalid_coverage_report") { validate(report) }
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def coverage_document
    coverage = SpecProof::Coverage.new(obligations: @obligations, specifications: @specifications)
    coverage.observe(target: "ConstrainedPairwise#call", arguments: { a: true, b: true })
    adapter_document(specifications: @specifications, projection: coverage.to_report)
  end

  def adapter_document(specifications:, projection:)
    projection = projection.transform_keys(&:to_s)
    adapter_scope = {
      "ruby_engine" => RUBY_ENGINE, "pid" => Process.pid, "thread" => Thread.current.object_id,
      "window" => "minitest_run", "method_identity" => "direct_owner_definition",
      "input_semantics" => "effective_bound_values", "argument_presence" => "not_observed",
      "targets" => specifications.map(&:target),
      "declaration_sources" => { "specifications" => [], "rbs" => [], "targets" => [] },
      "arguments" => [], "filter" => nil, "exclude" => nil
    }.merge(SpecProof::Report.input_scope(specifications).transform_keys(&:to_s))
    JSON.parse(JSON.generate({
      "schema_version" => 1, "kind" => "coverage", "errors" => [],
      "contract_digest" => SpecProof::Report.digest(specifications),
      "criterion" => CRITERION, "run_id" => "run-123", "scope" => adapter_scope,
      "evidence_mode" => "obligation_hits", "replay" => false,
      "completion" => "completed", "integrity" => true, "tests_passed" => true
    }.merge(projection)))
  end

  def integer_pair_specifications
    source = SpecProof::Source.new(path: "integer_pairs.rb", line: 1)
    inputs = %i[left right].to_h do |name|
      input = SpecProof::Input.new(name: name, domain: SpecProof::Domains.from_values([1, 2]), partitions: [],
                                   exhaustive: false, disjoint: false, source: source)
      [name, input]
    end
    group = SpecProof::CombinationGroup.new(inputs: inputs.keys, forbidden: [], source: source)
    [SpecProof::Specification.new(target: "IntegerPairs#call", inputs: inputs, source: source,
                                  combination_group: group)]
  end

  def tamper_integer_encodings(rows)
    rows.each do |row|
      row.fetch("inputs").each_value do |typed|
        typed["value"] = 1.0 if typed.fetch("kind") == "integer"
      end
    end
  end

  def validate(document)
    SpecProof::CoverageReport.new(document, specifications: @specifications, obligations: @obligations)
  end

  def assert_mutations(cases)
    cases.each do |label, code, mutation|
      report = coverage_document
      mutation.call(report)
      error = assert_raises(SpecProof::ConfigurationError, label) { validate(report) }
      assert_equal code, error.code, label
    end
  end

  def assert_error(code, &)
    error = assert_raises(SpecProof::ConfigurationError, &)
    assert_equal code, error.code
  end
end
