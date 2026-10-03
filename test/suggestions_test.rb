# frozen_string_literal: true

require "test_helper"
require "tempfile"

class SuggestionsTest < Minitest::Test
  def test_combination_space_exposes_frozen_allowed_assignments
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#constrained" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :c, :a, :b do
          forbid a: false, b: false, c: false
        end
      end
    RUBY

    assignments = SpecProof::CombinationSpace.new(specifications.first).allowed_assignments

    assert_equal [
      { a: false, b: false, c: true },
      { a: false, b: true, c: false },
      { a: false, b: true, c: true },
      { a: true, b: false, c: false },
      { a: true, b: false, c: true },
      { a: true, b: true, c: false },
      { a: true, b: true, c: true }
    ], assignments
    assert_predicate assignments, :frozen?
    assert(assignments.all?(&:frozen?))
  end

  def test_two_boolean_inputs_suggest_only_the_unobserved_pair
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#two" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    [{ a: false, b: false }, { a: false, b: true }, { a: true, b: false }].each do |inputs|
      coverage.observe(target: "Example#two", arguments: inputs)
    end
    report = coverage_report(specifications, obligations, coverage, tests_passed: false)

    result = SpecProof.suggest(specifications, report: report)

    assert_equal [{ a: true, b: true }], result.suggestions.map(&:inputs)
    assert_equal 1, result.missing_count
    assert_equal false, result.source_tests_passed
    assert_equal [obligations.last.id], result.suggestions.first.covers
  end

  def test_three_boolean_inputs_suggest_a_deterministic_pairwise_cover
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#three" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))

    first = SpecProof.suggest(specifications, report: report)
    second = SpecProof.suggest(specifications, report: report)

    first_rows = first.suggestions.map { |item| [item.id, item.inputs, item.covers] }
    second_rows = second.suggestions.map { |item| [item.id, item.inputs, item.covers] }
    assert_equal first_rows, second_rows
    assert_equal [
      { a: false, b: false, c: false },
      { a: false, b: true, c: true },
      { a: true, b: false, c: true },
      { a: true, b: true, c: false }
    ], first.suggestions.map(&:inputs)
    assert_equal obligations.map(&:id).sort, first.suggestions.flat_map(&:covers).sort
    assert(first.suggestions.all? { |item| !item.covers.empty? })
  end

  def test_forbidden_full_assignments_never_appear_in_suggestions
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#forbidden" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: false, b: false, c: false
        end
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))

    result = SpecProof.suggest(specifications, report: report)

    refute_includes result.suggestions.map(&:inputs), { a: false, b: false, c: false }
    assert_equal obligations.map(&:id).sort, result.suggestions.flat_map(&:covers).sort
  end

  def test_indirectly_excluded_pair_is_never_combined_into_a_suggestion
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#indirect" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: false, c: false
          forbid b: false, c: true
        end
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))

    result = SpecProof.suggest(specifications, report: report)

    assert(obligations.any? { |item| item.inputs == { a: false, c: true } })
    assert(obligations.any? { |item| item.inputs == { b: false, c: false } })
    refute(result.suggestions.any? { |item| item.inputs.values_at(:a, :b) == [false, false] })
    assert_equal obligations.map(&:id).sort, result.suggestions.flat_map(&:covers).sort
  end

  def test_suggestions_follow_sorted_target_order_even_when_later_target_has_more_gain
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#zeta" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c, all_allowed: true
      end

      SpecProof.define "Example#alpha" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))

    result = SpecProof.suggest(specifications, report: report)

    assert_equal ["Example#alpha", "Example#zeta"], result.suggestions.map(&:target).uniq
    assert(result.suggestions.index { |item| item.target == "Example#alpha" } <
           result.suggestions.index { |item| item.target == "Example#zeta" })
  end

  def test_empty_missing_set_returns_frozen_empty_result
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#covered" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    [false, true].product([false, true]).each do |a, b|
      coverage.observe(target: "Example#covered", arguments: { a: a, b: b })
    end

    result = SpecProof.suggest(specifications, report: coverage_report(specifications, obligations, coverage))

    assert_empty result.suggestions
    assert result.suggestions.frozen?
    assert_equal 0, result.missing_count
  end

  def test_symbol_and_string_values_remain_distinct_in_assignments_and_ids
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#typed" do
        input :mode, values: [:ready, "ready"]
        input :enabled, values: [false, true]
        combinations :mode, :enabled, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))

    result = SpecProof.suggest(specifications, report: report)

    assert_equal 4, result.suggestions.length
    assert_equal [String, Symbol], result.suggestions.map { |item| item.inputs.fetch(:mode).class }.uniq.sort_by(&:name)
    assert_equal 4, result.suggestions.map(&:id).uniq.length
    frozen_inputs = result.suggestions.all? do |item|
      item.inputs.frozen? && item.inputs.values.all? { |value| !value.is_a?(String) || value.frozen? }
    end
    assert frozen_inputs
  end

  def test_suggestion_result_owns_its_scope_snapshot
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#scope" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))
    mutable_run_id = report.fetch("run_id")
    mutable_argument = +"--name"
    report.fetch("scope").fetch("arguments") << mutable_argument

    result = SpecProof.suggest(specifications, report: report)
    mutable_run_id.replace("changed")
    mutable_argument.replace("changed")

    assert_equal "test-run-1", result.source_run_id
    assert result.source_scope.frozen?
    assert result.source_scope.fetch("arguments").frozen?
    assert_equal "--name", result.source_scope.fetch("arguments").last
  end

  def test_inputs_outside_group_and_excluded_inputs_are_reported_as_unassigned
    specifications = load_text(<<~RUBY)
      SpecProof.define "Example#partial" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :context, values: [:local, :remote]
        exclude_input :payload, reason: "payload is outside this finite contract"
        combinations :a, :b, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))
    report.fetch("scope")["arguments"] = ["--name", "some-test"]
    report.fetch("scope")["filter"] = "some-test"

    result = SpecProof.suggest(specifications, report: report)

    assert(result.suggestions.all? { |item| item.unassigned_inputs == %i[context payload] })
    assert_equal ["--name", "some-test"], result.source_scope.fetch("arguments")
    assert_equal "some-test", result.source_scope.fetch("filter")
  end

  def test_declaration_and_report_row_order_do_not_change_assignments_or_ids
    first_specs = load_text(<<~RUBY)
      SpecProof.define "Example#ordered" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: false, b: false
          forbid b: true, c: true
        end
      end
    RUBY
    second_specs = load_text(<<~RUBY)
      SpecProof.define "Example#ordered" do
        input :c, values: [true, false]
        input :b, values: [true, false]
        input :a, values: [true, false]
        combinations :c, :b, :a do
          forbid c: true, b: true
          forbid b: false, a: false
        end
      end
    RUBY
    first_obligations = SpecProof.plan(first_specs, criterion: "pairwise-finite-v1")
    second_obligations = SpecProof.plan(second_specs, criterion: "pairwise-finite-v1")
    first_report = coverage_report(first_specs, first_obligations,
                                   SpecProof::Coverage.new(obligations: first_obligations, specifications: first_specs))
    second_report = coverage_report(second_specs, second_obligations,
                                    SpecProof::Coverage.new(obligations: second_obligations,
                                                            specifications: second_specs))
    second_report.fetch("obligations").reverse!
    second_report.fetch("missing").reverse!

    first = SpecProof.suggest(first_specs, report: first_report)
    second = SpecProof.suggest(second_specs, report: second_report)

    first_rows = first.suggestions.map { |item| [item.id, item.inputs, item.covers] }
    second_rows = second.suggestions.map { |item| [item.id, item.inputs, item.covers] }
    assert_equal first_rows, second_rows
  end

  def test_cumulative_assignment_budget_is_rejected_before_report_validation
    specifications = finite_boolean_specifications(count: 2_501, input_count: 2)
    enumerations = 0
    trace = TracePoint.new(:call) do |event|
      enumerations += 1 if event.defined_class == SpecProof::CombinationSpace && event.method_id == :enumerate
    end

    trace.enable
    begin
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.suggest(specifications, report: {})
      end
    ensure
      trace.disable
    end

    assert_equal "suggestion_limit_exceeded", error.code
    assert_equal 0, enumerations
  end

  def test_cumulative_pair_row_budget_is_rejected_across_targets
    specifications = finite_boolean_specifications(count: 417, input_count: 4)

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.suggest(specifications, report: {})
    end

    assert_equal "suggestion_limit_exceeded", error.code
  end

  def test_candidate_to_missing_pair_membership_budget_returns_no_partial_result
    specifications = [many_input_specification(binary_count: 13, singleton_count: 4)]
    obligations = SpecProof.plan(specifications, criterion: "pairwise-finite-v1")
    report = coverage_report(specifications, obligations,
                             SpecProof::Coverage.new(obligations: obligations, specifications: specifications))
    result = nil

    error = assert_raises(SpecProof::ConfigurationError) do
      result = SpecProof.suggest(specifications, report: report)
    end

    assert_equal "suggestion_limit_exceeded", error.code
    assert_nil result
  end

  def test_many_singleton_inputs_hit_pair_limit_before_combination_enumeration
    specifications = [many_input_specification(binary_count: 0, singleton_count: 10_000)]
    enumerations = 0
    trace = TracePoint.new(:call) do |event|
      enumerations += 1 if event.defined_class == SpecProof::CombinationSpace && event.method_id == :enumerate
    end

    trace.enable
    begin
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.suggest(specifications, report: {})
      end
    ensure
      trace.disable
    end

    assert_equal "combination_limit_exceeded", error.code
    assert_match "possible pair rows", error.message
    assert_equal 0, enumerations
  end

  private

  def load_text(text)
    Tempfile.create(["suggestions", ".rb"]) do |file|
      file.write(text)
      file.flush
      SpecProof.load([file.path])
    end
  end

  def coverage_report(specifications, _obligations, coverage, tests_passed: true)
    runtime_scope = {
      ruby_engine: RUBY_ENGINE,
      pid: Process.pid,
      thread: Thread.current.object_id,
      window: "minitest_run",
      method_identity: "direct_owner_definition",
      input_semantics: "effective_bound_values",
      argument_presence: "not_observed",
      targets: specifications.map(&:target).sort,
      declaration_sources: { specifications: [], rbs: [], targets: [] },
      arguments: [], filter: nil, exclude: nil
    }
    projection = coverage.to_report
    document = SpecProof::Report.envelope(kind: "coverage").merge(
      contract_digest: SpecProof::Report.digest(specifications),
      criterion: "pairwise-finite-v1",
      run_id: "test-run-1",
      scope: runtime_scope.merge(SpecProof::Report.input_scope(specifications)),
      completion: "completed",
      integrity: true,
      tests_passed: tests_passed,
      evidence_mode: "obligation_hits",
      replay: false
    ).merge(projection.except(:status, :completeness))
    JSON.parse(JSON.generate(document))
  end

  def finite_boolean_specifications(count:, input_count:)
    source = SpecProof::Source.new(path: "suggestions.rb", line: 1)
    domain = SpecProof::FiniteDomain.new(values: [false, true])
    Array.new(count) do |index|
      target = format("Example%04d#call", index)
      inputs = input_count.times.to_h do |offset|
        name = ("a".ord + offset).chr.to_sym
        [name, SpecProof::Input.new(name: name, domain: domain, partitions: [], exhaustive: false,
                                    disjoint: false, source: source)]
      end
      group = SpecProof::CombinationGroup.new(inputs: inputs.keys, forbidden: [], source: source)
      SpecProof::Specification.new(target: target, inputs: inputs, source: source, combination_group: group)
    end
  end

  def many_input_specification(binary_count:, singleton_count:)
    source = SpecProof::Source.new(path: "suggestions.rb", line: 1)
    binary = SpecProof::FiniteDomain.new(values: [false, true])
    singleton = SpecProof::FiniteDomain.new(values: [:fixed])
    names = Array.new(binary_count + singleton_count) { |index| format("input_%02d", index) }
    inputs = names.each_with_index.to_h do |name, index|
      domain = index < binary_count ? binary : singleton
      key = name.to_sym
      [key, SpecProof::Input.new(name: key, domain: domain, partitions: [], exhaustive: false,
                                 disjoint: false, source: source)]
    end
    group = SpecProof::CombinationGroup.new(inputs: inputs.keys, forbidden: [], source: source)
    SpecProof::Specification.new(target: "Example#many", inputs: inputs, source: source,
                                 combination_group: group)
  end
end
