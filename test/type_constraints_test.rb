# frozen_string_literal: true

require "test_helper"

class TypeConstraintsTest < Minitest::Test
  def test_constraint_normalizes_and_freezes_values
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: true, values: [3, :ro, nil, :ro, 1])

    assert_equal [:ro, nil].sort_by { |value| SpecProof::Domains.sort_key(value) }, constraint.values
    assert constraint.frozen?
    assert constraint.values.frozen?
  end

  def test_constraint_requires_a_boolean_flag_and_supported_values
    assert_raises(ArgumentError) do
      SpecProof::ScalarTypeConstraint.new(integer_any: :yes, values: [])
    end
    assert_raises(ArgumentError) do
      SpecProof::ScalarTypeConstraint.new(integer_any: false, values: ["\xFF".dup.force_encoding(Encoding::UTF_8)])
    end
  end

  def test_membership_uses_primitive_identity
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [nil, false, true, 1, :ro, "ro"])

    [nil, false, true, 1, :ro, "ro"].each { |value| assert SpecProof::TypeConstraints.include?(constraint, value) }
    [1.0, "other", Object.new, Class.new(String).new("ro")].each do |value|
      refute SpecProof::TypeConstraints.include?(constraint, value)
    end
  end

  def test_string_constraint_values_are_snapshotted_and_compose_with_finite_domains
    declared = +"known"
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [declared, :known])
    domain = SpecProof::Domains.from_values(["known", :known, "outside"])
    input = SpecProof::Input.new(name: :value, domain: domain, partitions: [], exhaustive: false,
                                 disjoint: false, source: SpecProof::Source.new(path: "x.rb", line: 1),
                                 type_constraint: constraint)
    specification = SpecProof::Specification.new(target: "Strings#call", inputs: { value: input },
                                                 source: input.source)

    declared.replace("mutated")
    assert constraint.values.last.frozen?
    assert_equal [:known, "known"], constraint.values
    assert SpecProof::TypeConstraints.include?(constraint, "known")
    refute SpecProof::TypeConstraints.include?(constraint, Class.new(String).new("known"))
    finding = SpecProof::Checker.new([specification]).findings.find { |item| item.code == :type_domain_conflict }
    assert_equal "outside", finding.witness
    assert_equal ["known"], SpecProof::TypeConstraints.finite_domain(constraint).values.grep(String)
  end

  def test_integer_any_accepts_every_integer_and_has_no_finite_projection
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: true, values: [:ro, nil])

    assert SpecProof::TypeConstraints.include?(constraint, -(10**100))
    refute SpecProof::TypeConstraints.include?(constraint, 1.0)
    assert_nil SpecProof::TypeConstraints.finite_domain(constraint)
  end

  def test_finite_projection_keeps_nullable_scalar_members
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [nil, false, :ro])

    assert_equal [nil, false, :ro], SpecProof::TypeConstraints.finite_domain(constraint).values
  end

  def test_first_excluded_finite_witness_preserves_nil_and_sentinel_identity
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [false, true, :none])
    domain = SpecProof::FiniteDomain.new([nil, false, true, :none])

    assert_nil SpecProof::TypeConstraints.first_excluded(constraint, domain)
    assert_same SpecProof::TypeConstraints::NO_EXCLUSION,
                SpecProof::TypeConstraints.first_excluded(constraint, SpecProof::FiniteDomain.new([false, true]))
    refute_equal :none, SpecProof::TypeConstraints::NO_EXCLUSION
  end

  def test_first_excluded_integer_witness_scans_declared_values_only
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [0, 1, 3])
    domain = SpecProof::IntegerDomain.new(lower: 0, upper: 10**100)

    assert_equal 2, SpecProof::TypeConstraints.first_excluded(constraint, domain)
  end

  def test_integer_any_covers_integer_intervals_and_empty_domains_have_no_witness
    constraint = SpecProof::ScalarTypeConstraint.new(integer_any: true, values: [:ro])

    interval = SpecProof::IntegerDomain.new(lower: -10, upper: 10)
    assert_same SpecProof::TypeConstraints::NO_EXCLUSION,
                SpecProof::TypeConstraints.first_excluded(constraint, interval)
    empty = SpecProof::IntegerDomain.new(lower: 4, upper: 3)
    assert_same SpecProof::TypeConstraints::NO_EXCLUSION,
                SpecProof::TypeConstraints.first_excluded(constraint, empty)
    assert_same SpecProof::TypeConstraints::NO_EXCLUSION,
                SpecProof::TypeConstraints.first_excluded(constraint, SpecProof::FiniteDomain.new([]))
  end

  def test_union_is_a_closed_scalar_union
    first = SpecProof::ScalarTypeConstraint.new(integer_any: false, values: [1, :ro])
    second = SpecProof::ScalarTypeConstraint.new(integer_any: true, values: [1, nil])
    merged = SpecProof::TypeConstraints.union([first, second])

    assert_equal true, merged.integer_any
    assert_equal [nil, :ro].sort_by { |value| SpecProof::Domains.sort_key(value) }, merged.values
  end

  def test_source_kind_and_input_type_sources_are_immutable_and_deterministic
    primary = SpecProof::Source.new(path: "z.rb", line: 4)
    rbs = SpecProof::Source.new(path: "a.rbs", line: 9, kind: "rbs")
    dsl = SpecProof::Source.new(path: "a.rb", line: 9)
    input = SpecProof::Input.new(name: :value, domain: nil, partitions: [], exhaustive: false,
                                 disjoint: false, source: primary, type_constraint: nil,
                                 type_sources: [rbs, dsl, rbs])

    assert_equal "dsl", primary.kind
    assert_equal "rbs", rbs.kind
    assert primary.kind.frozen?
    assert_equal [dsl, rbs, primary], input.sources
    assert input.type_sources.frozen?
    assert input.frozen?

    fact = SpecProof::InputTypeFact.new(target: "Example#value", input: :value,
                                        constraint: input.type_constraint, source: rbs)
    assert fact.frozen?
    assert fact.target.frozen?
    assert_equal :value, fact.input
  end

  def test_source_report_includes_additive_kind
    source = SpecProof::Source.new(path: "example.rbs", line: 7, kind: "rbs")

    assert_equal({ path: "example.rbs", line: 7, kind: "rbs" }, SpecProof::Report.source(source))
  end
end
