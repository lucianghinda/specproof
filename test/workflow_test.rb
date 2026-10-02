# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class WorkflowTest < Minitest::Test
  # This integration check states several independent report invariants.
  def test_correct_age_policy_exercises_all_six_candidates
    report, status, transcript = run_example(faulty: false)

    assert status.success?, transcript
    second_report, second_status, second_stderr = run_example(faulty: false)
    assert second_status.success?, second_stderr
    refute_equal report.fetch("run_id"), second_report.fetch("run_id")
    assert_includes transcript, report.fetch("run_id")
    assert_equal true, report.fetch("tests_passed")
    assert_equal true, report.fetch("integrity")
    assert_equal "completed", report.fetch("completion")
    assert_equal "coverage", report.fetch("kind")
    assert_equal "input-basics-v1", report.fetch("criterion")
    assert_complete_coverage_report(report)
  end

  def test_faulty_boundary_is_visible_even_when_examples_pass
    report, status, stderr = run_example(faulty: true, explicit_boundary: false)

    assert status.success?, stderr
    assert_equal true, report.fetch("tests_passed")
    assert_equal 5, report.fetch("exercised_count")
    missing_values = report.fetch("obligations").select { |row| row.fetch("status") == "not_observed" }
    values = missing_values.map { |row| row.dig("value", "value") }
    assert_equal ["18"], values
  end

  def test_explicit_boundary_assertion_fails_without_suppressing_collection
    report, status, _stderr = run_example(faulty: true, explicit_boundary: true)

    refute status.success?
    assert_equal false, report.fetch("tests_passed")
    assert_equal true, report.fetch("integrity")
    assert_equal "completed", report.fetch("completion")
    boundary = report.fetch("obligations").find { |row| row.dig("value", "value") == "18" }
    assert_equal "exercised", boundary.fetch("status")
    assert_equal 1, boundary.fetch("hits")
  end

  def test_missing_obligations_only_fail_when_opted_in
    report, status, _stderr = run_example(
      faulty: true, explicit_boundary: false, fail_on_missing: true
    )

    refute status.success?
    assert_equal true, report.fetch("tests_passed")
    assert_equal true, report.fetch("integrity")
    assert_equal 1, report.fetch("missing_count")
  end

  def test_partition_gap_example_is_a_semantic_finding
    stdout, stderr, status = Open3.capture3(
      { "RUBYOPT" => nil },
      RbConfig.ruby, "-Ilib", "exe/specproof", "check", "examples/partition_gap.rb", "--format", "json",
      chdir: File.expand_path("..", __dir__)
    )

    assert_equal 1, status.exitstatus, stderr
    result = JSON.parse(stdout)
    assert_equal "partition_gap", result.fetch("findings").fetch(0).fetch("code")
  end

  private

  def assert_complete_coverage_report(report)
    assert_equal 1, report.fetch("schema_version")
    assert_equal SpecProof::VERSION, report.fetch("specproof_version")
    assert_match(/\A[0-9a-f]{64}\z/, report.fetch("contract_digest"))
    assert_match(/\A.+\z/, report.fetch("run_id"))
    assert_equal "obligation_hits", report.fetch("evidence_mode")
    assert_equal false, report.fetch("replay")
    counts = %w[obligation_count exercised_count missing_count].map { |key| report.fetch(key) }
    assert_equal [6, 6, 0], counts
    rows = report.fetch("obligations")
    values = rows.map { |row| row.dig("value", "value") }
    assert_equal %w[0 1 17 18 119 120], values
    assert(rows.all? { |row| row.dig("value", "kind") == "integer" })
    assert(rows.all? { |row| row.fetch("status") == "exercised" && row.fetch("hits").positive? })
  end

  # Test harness setup stays together so each subprocess uses an isolated report and run.
  def run_example(faulty:, explicit_boundary: false, fail_on_missing: false)
    Dir.mktmpdir("specproof-workflow-") do |directory|
      output = File.join(directory, "coverage.json")
      mode = if !faulty
               "correct"
             elsif explicit_boundary
               "regression"
             else
               "missing"
             end
      runner = File.expand_path("../examples/age_policy/run.rb", __dir__)
      stdout, stderr, status = Open3.capture3(
        { "RUBYOPT" => nil, "SPECPROOF_STRICT" => fail_on_missing ? "1" : "0" },
        RbConfig.ruby, "-Ilib", runner, mode, output,
        chdir: File.expand_path("..", __dir__)
      )
      # Minitest writes the structured report before process exit, including
      # when a test assertion fails.
      flunk("Minitest adapter produced no report. stdout:\n#{stdout}\nstderr:\n#{stderr}") unless File.file?(output)

      [JSON.parse(File.read(output)), status, [stdout, stderr].join]
    end
  end
end
