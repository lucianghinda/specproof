# frozen_string_literal: true

require "test_helper"
require "digest"
require "json"
require "tempfile"

class PairwisePlannerTest < Minitest::Test
  CRITERION = "pairwise-finite-v1"

  def test_two_and_three_boolean_inputs_plan_each_feasible_pair_once
    two = load_text(<<~RUBY)
      SpecProof.define "Example#two" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :b, :a, all_allowed: true
      end
    RUBY
    three = load_text(<<~RUBY)
      SpecProof.define "Example#three" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c, all_allowed: true
      end
    RUBY

    assert_equal 4, SpecProof.plan(two, criterion: CRITERION).length
    obligations = SpecProof.plan(three, criterion: CRITERION)
    assert_equal 12, obligations.length
    assert(obligations.all? { |item| item.inputs.frozen? && item.inputs.length == 2 })
    assert_equal obligations.map(&:id).sort, SpecProof.plan(three, criterion: CRITERION).map(&:id).sort
  end

  def test_forbidden_pair_is_excluded_and_other_pairs_remain_required
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#constrained" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b do
          forbid a: false, b: false
        end
      end
    RUBY

    space = SpecProof::CombinationSpace.new(specs.first)
    assert_equal 3, space.allowed_count
    assert_equal 3, space.pairs.length
    assert_equal [{ a: false, b: false }], space.excluded_pairs
    assert_equal 4, specs.first.combination_group.source.line
    assert_equal 5, specs.first.combination_group.forbidden.first.source.line
  end

  def test_pair_is_excluded_only_after_considering_all_completions
    specs = load_text(<<~RUBY)
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

    space = SpecProof::CombinationSpace.new(specs.first)
    assert space.allowed?({ a: false, b: true, c: true })
    assert space.allowed?({ a: true, b: false, c: false })
    assert_includes space.excluded_pairs, { a: false, b: false }
  end

  def test_unsatisfiable_group_is_a_semantic_finding
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#impossible" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        combinations :a, :b do
          forbid a: false
          forbid a: true
        end
      end
    RUBY

    finding = SpecProof.check(specs).find { |item| item.code == :unsatisfiable_combinations }
    assert_instance_of SpecProof::CombinationFinding, finding
    assert_equal %i[a b], finding.inputs
    error = assert_raises(SpecProof::InvalidSpecificationError) do
      SpecProof.plan(specs, criterion: CRITERION)
    end
    assert_equal [:unsatisfiable_combinations], error.findings.map(&:code)
  end

  def test_empty_group_domain_short_circuits_joint_assignment_enumeration
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#empty" do
        input :a, values: (1..10_000).to_a
        input :b, values: []
        combinations :a, :b, all_allowed: true
      end
    RUBY

    space = SpecProof::CombinationSpace.new(specs.first)
    assert_equal 0, space.allowed_count
    assert_empty space.pairs
    assert_empty space.excluded_pairs
  end

  def test_pair_row_limit_is_rejected_during_preflight
    error = assert_raises(SpecProof::ConfigurationError) do
      load_text(<<~RUBY)
        SpecProof.define "Example#large" do
          input :a, values: (1..101).to_a
          input :b, values: (1..100).to_a
          combinations :a, :b, all_allowed: true
        end
      RUBY
    end
    assert_equal "combination_limit_exceeded", error.code
  end

  def test_total_pair_limit_stops_before_planning_later_targets
    source = SpecProof::Source.new(path: "pairwise.rb", line: 1)
    domain = SpecProof::FiniteDomain.new(values: [false, true])
    specifications = (0..2_500).map do |index|
      target = "Example#{index}#call"
      inputs = %i[a b].to_h do |name|
        [name, SpecProof::Input.new(name: name, domain: domain, partitions: [], exhaustive: false, disjoint: false,
                                    source: source)]
      end
      group = SpecProof::CombinationGroup.new(inputs: %i[a b], forbidden: [], source: source)
      SpecProof::Specification.new(target: target, inputs: inputs, source: source, combination_group: group)
    end
    later_target = "ExampleLater#call"
    specifications << SpecProof::Specification.new(target: later_target, inputs: {}, source: source)

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.plan(specifications, criterion: CRITERION)
    end

    assert_equal "combination_limit_exceeded", error.code
    assert_includes error.message, "10004 pair obligations"
  end

  def test_combination_metadata_owns_strings_and_is_deeply_frozen
    source = SpecProof::Source.new(path: "pairwise.rb", line: 1)
    original = +"ready"
    assignment = SpecProof::ForbiddenAssignment.new(assignments: { mode: original }, source: source)
    original << " now"

    assert_equal "ready", assignment.assignments.fetch(:mode)
    assert assignment.frozen?
    assert assignment.assignments.frozen?
    assert assignment.assignments.fetch(:mode).frozen?
  end

  def test_combinations_rejects_missing_modes_and_unknown_options
    [
      ["combinations :a, :b", "invalid_combinations_mode"],
      ["combinations :a, :b, all_allowed: false", "invalid_combinations_mode"],
      ["combinations :a, :b, allowed: true", "unknown_option"]
    ].each do |declaration, expected_code|
      error = assert_raises(SpecProof::ConfigurationError) do
        load_text(<<~RUBY)
          SpecProof.define "Example#mode" do
            input :a, values: [false, true]
            input :b, values: [false, true]
            #{declaration}
          end
        RUBY
      end
      assert_equal expected_code, error.code
    end
  end

  def test_equivalent_group_order_and_duplicate_rules_preserve_digest_and_pair_ids
    first = load_text(<<~RUBY)
      SpecProof.define "Example#canonical" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: false, b: false
          forbid c: true
        end
      end
    RUBY
    equivalent = load_text(<<~RUBY)
      SpecProof.define "Example#canonical" do
        input :c, values: [true, false]
        input :b, values: [true, false]
        input :a, values: [true, false]
        combinations :c, :a, :b do
          forbid c: true
          forbid b: false, a: false
          forbid a: false, b: false
        end
      end
    RUBY
    changed = load_text(<<~RUBY)
      SpecProof.define "Example#canonical" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: false, b: false
          forbid c: false
        end
      end
    RUBY

    assert_equal SpecProof::Report.digest(first), SpecProof::Report.digest(equivalent)
    refute_equal SpecProof::Report.digest(first), SpecProof::Report.digest(changed)
    first_obligations = SpecProof.plan(first, criterion: CRITERION)
    equivalent_obligations = SpecProof.plan(equivalent, criterion: CRITERION)
    assert_equal first_obligations.map(&:id).sort, equivalent_obligations.map(&:id).sort

    sources = equivalent.first.combination_group.forbidden.map(&:source)
    space_sources = SpecProof::CombinationSpace.new(equivalent.first).sources
    assert_equal 3, sources.length
    assert(sources.all? { |source| space_sources.include?(source) })
    assert(sources.all? { |source| equivalent_obligations.first.sources.include?(source) })
  end

  def test_malformed_combinations_declarations_fail_with_concrete_sources
    cases = [
      ["combinations :a, :a, all_allowed: true", "invalid_combination_inputs"],
      ["combinations :a, :b, all_allowed: true\ncombinations :a, :b, all_allowed: true", "duplicate_combinations"],
      ["combinations :a, :b do\nend", "empty_combinations_block"],
      ["combinations :a, :b, all_allowed: true do\n  forbid a: false\nend", "invalid_combinations_mode"],
      ["combinations :a, :b do\n  forbid\nend", "empty_forbidden_assignment"],
      ["combinations :a, :b do\n  forbid c: false\nend", "unknown_forbidden_input"]
    ]
    cases.each do |declaration, expected_code|
      error = assert_raises(SpecProof::ConfigurationError) do
        load_text(<<~RUBY)
          SpecProof.define "Example#malformed" do
            input :a, values: [false, true]
            input :b, values: [false, true]
            input :c, values: [false, true]
            #{declaration}
          end
        RUBY
      end
      assert_equal expected_code, error.code
      assert_instance_of SpecProof::Source, error.source
    end

    error = assert_raises(SpecProof::ConfigurationError) do
      load_text(<<~RUBY)
        SpecProof.define "Example#excluded" do
          exclude_input :a, reason: "outside analyzed scope"
          input :b, values: [false, true]
          input :c, values: [false, true]
          combinations :a, :b, all_allowed: true
        end
      RUBY
    end
    assert_equal "excluded_combination_input", error.code
    assert_instance_of SpecProof::Source, error.source
  end

  def test_bad_group_members_and_rule_values_are_configuration_errors
    missing = load_text(<<~RUBY, allow_rbs_group: true)
      SpecProof.define "Example#missing" do
        combinations :a, :b, all_allowed: true
      end
    RUBY
    error = assert_raises(SpecProof::ConfigurationError) { SpecProof::CombinationSpace.new(missing.first) }
    assert_equal "unknown_combination_input", error.code

    error = assert_raises(SpecProof::ConfigurationError) do
      load_text(<<~RUBY)
        SpecProof.define "Example#invalid" do
          input :a, values: [1, 3]
          input :b, values: [false, true]
          combinations :a, :b do
            forbid a: 4
          end
        end
      RUBY
    end
    assert_equal "invalid_combination_value", error.code

    error = assert_raises(SpecProof::ConfigurationError) do
      load_text(<<~RUBY)
        SpecProof.define "Example#range" do
          input :a, range: 1..3
          input :b, values: [false, true]
          combinations :a, :b, all_allowed: true
        end
      RUBY
    end
    assert_equal "finite_combinations_required", error.code
  end

  def test_pairwise_requires_finite_domains_and_a_group_for_every_target
    error = assert_raises(SpecProof::ConfigurationError) do
      load_text(<<~RUBY)
        SpecProof.define "Example#range" do
          input :a, range: 1..3
          input :b, values: [false, true]
          combinations :a, :b, all_allowed: true
        end
      RUBY
    end
    assert_equal "finite_combinations_required", error.code

    no_group = load_text(<<~RUBY)
      SpecProof.define "Example#plain" do
        input :a, values: [1]
      end
    RUBY
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.plan(no_group, criterion: CRITERION)
    end
    assert_equal "combinations_required", error.code
  end

  def test_pair_ids_preserve_string_and_symbol_values_and_ignore_declaration_order
    first = load_text(<<~RUBY)
      SpecProof.define "Example#typed" do
        input :a, values: [:ready, "ready"]
        input :b, values: [1]
        combinations :a, :b, all_allowed: true
      end
    RUBY
    second = load_text(<<~RUBY)
      SpecProof.define "Example#typed" do
        input :b, values: [1]
        input :a, values: ["ready", :ready]
        combinations :b, :a, all_allowed: true
      end
    RUBY

    left = SpecProof.plan(first, criterion: CRITERION)
    right = SpecProof.plan(second, criterion: CRITERION)
    assert_equal left.map(&:id).sort, right.map(&:id).sort
    assert_equal 2, left.map(&:id).uniq.length
    assert_equal %w[string symbol], left.map { |item| SpecProof::Report.value(item.inputs.fetch(:a)).fetch(:kind) }.sort
  end

  def test_scalar_obligation_identity_keeps_its_legacy_hash_shape
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#scalar" do
        input :enabled, values: [false, true]
      end
    RUBY

    obligation = SpecProof.plan(specs).first
    expected = Digest::SHA256.hexdigest(
      JSON.generate(["Example#scalar", "enabled", SpecProof::Report.value(false), "input-basics-v1"])
    )
    assert_equal expected, obligation.id
  end

  private

  def load_text(content, allow_rbs_group: false)
    Tempfile.create(["specproof-pairwise", ".rb"]) do |file|
      file.write(content)
      file.flush
      if allow_rbs_group
        SpecProof::Loader.load([file.path], allow_exclusion_only: true)
      else
        SpecProof.load([file.path])
      end
    end
  end
end
