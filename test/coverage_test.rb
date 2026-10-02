# frozen_string_literal: true

require "test_helper"
require_relative "../lib/specproof/coverage"

class CoverageTest < Minitest::Test
  def test_age_inputs_count_once_and_missing_value_has_stable_obligation_id
    specifications = SpecProof.load([fixture("age_policy_moved.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    [0, 1, 17, 119, 120].each do |age|
      coverage.observe(target: "AgePolicy#adult?", arguments: { age: age })
    end

    report = coverage.to_report
    assert_equal 5, report.fetch(:exercised_count)
    assert_equal 1, report.fetch(:missing_count)
    assert_equal 83.33, report.fetch(:completion_percent)
    assert_equal([{ kind: "integer", value: "18" }], report.fetch(:missing).map { |item| item.fetch(:value) })
    assert_equal "not_observed", report.fetch(:missing).first.fetch(:status)
    assert_equal obligations.find { |item| item.value == 18 }.id, report.fetch(:missing).first.fetch(:id)
    assert_equal "obligation_hits", report.fetch(:evidence_mode)
    assert_equal false, report.fetch(:replay)
  end

  def test_finite_values_support_symbols_booleans_integers_and_nil
    specifications = SpecProof.load([fixture("finite.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    [nil, false, true, 1, :ro].each do |value|
      coverage.observe(target: "Example#call", arguments: { value: value })
      coverage.observe(target: "Example#call", arguments: { value: value })
    end

    report = coverage.to_report
    assert_equal 5, report.fetch(:exercised_count)
    assert_equal 0, report.fetch(:missing_count)
    assert_equal([2, 2, 2, 2, 2], report.fetch(:obligations).map { |item| item.fetch(:hits) })
  end

  def test_out_of_domain_argument_invalidates_the_entire_tuple
    specifications = SpecProof.load([fixture("age_policy_moved.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    coverage.observe(target: "AgePolicy#adult?", arguments: { age: 0, unrelated: :bad })
    report = coverage.to_report
    assert_equal 0, report.fetch(:exercised_count)
    assert_equal 1, report.fetch(:outside_domain).fetch("AgePolicy#adult?").fetch(:count)
    assert_equal({ "age" => { kind: "integer", value: "0" }, "unrelated" => { kind: "symbol", value: "bad" } },
                 report.fetch(:outside_domain).fetch("AgePolicy#adult?").fetch(:witness))
    assert_equal 6, report.fetch(:missing_count)
  end

  def test_every_declared_argument_must_be_in_domain_before_any_obligation_hits
    specifications = SpecProof.load([fixture("multiple_inputs.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    coverage.observe(target: "Calculator#call", arguments: { age: 0, mode: :unknown })

    report = coverage.to_report
    assert_equal 0, report.fetch(:exercised_count)
    assert_equal obligations.length, report.fetch(:missing_count)
    assert_equal 1, report.fetch(:outside_domain).fetch("Calculator#call").fetch(:count)
  end

  def test_zero_calls_are_not_observed_not_a_zero_percent_complete_result
    specifications = SpecProof.load([fixture("age_policy_moved.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    report = coverage.to_report
    assert_equal "not_observed", report.fetch(:status)
    assert_nil report.fetch(:completion_percent)
  end

  def test_incomplete_target_preserves_positive_hits_and_marks_unseen_unknown
    specifications = SpecProof.load([fixture("age_policy_moved.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    coverage.observe(target: "AgePolicy#adult?", arguments: { age: 0 })
    coverage.mark_incomplete(target: "AgePolicy#adult?", reason: "collector stopped")
    coverage.mark_incomplete(target: "AgePolicy#adult?", reason: "collector stopped")

    report = coverage.to_report
    assert_equal "incomplete", report.fetch(:completeness)
    assert_nil report.fetch(:completion_percent)
    assert_equal 1, report.fetch(:exercised_count)
    assert_equal 0, report.fetch(:missing_count)
    assert_equal 5, report.fetch(:unknown_count)
    assert_equal ["collector stopped"], report.fetch(:incomplete_reasons)
    assert_equal "exercised", report.fetch(:obligations).find { |item|
      item.fetch(:value) == { kind: "integer", value: "0" }
    }.fetch(:status)
    assert(report.fetch(:obligations).all? { |item| %w[exercised unknown].include?(item.fetch(:status)) })
  end

  def test_repeated_observations_keep_bounded_structural_counts
    specifications = SpecProof.load([fixture("age_policy_moved.rb")])
    obligations = SpecProof.plan(specifications)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    100_000.times { coverage.observe(target: "AgePolicy#adult?", arguments: { age: 0 }) }

    report = coverage.to_report
    row = report.fetch(:obligations).find { |item| item.fetch(:value) == { kind: "integer", value: "0" } }
    assert_equal 100_000, row.fetch(:hits)
    assert_equal 6, report.fetch(:obligations).length
    assert_equal false, report.key?(:trace)
    assert_equal false, report.key?(:raw_events)
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end
end
