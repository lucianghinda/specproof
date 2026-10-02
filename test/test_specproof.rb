# frozen_string_literal: true

require "test_helper"

class TestSpecProof < Minitest::Test
  def test_version_and_legacy_namespace
    assert_equal "0.1.0", SpecProof::VERSION
    assert_same SpecProof, Specproof
  end

  def test_range_declaration_checks_and_plans_boundaries
    specs = SpecProof.load([fixture("age_policy.rb")])
    findings = SpecProof.check(specs)
    plan = SpecProof.plan(specs)

    assert_empty findings
    assert_equal [0, 1, 17, 18, 119, 120], plan.map(&:value)
    assert plan.frozen?
    assert plan.all?(&:frozen?)
    assert_equal ["input lower endpoint", "minor lower endpoint"], plan.first.reasons
    assert_equal [2, 3], plan.first.sources.map(&:line)
    assert_equal fixture("age_policy.rb"), plan.first.sources.first.path
  end

  def test_gap_has_an_interval_witness_and_invalid_specs_cannot_be_planned
    specs = SpecProof.load([fixture("age_gap.rb")])
    finding = SpecProof.check(specs).fetch(0)

    assert_equal :partition_gap, finding.code
    assert_equal [65, 120], finding.witness
    error = assert_raises(SpecProof::InvalidSpecificationError) { SpecProof.plan(specs) }
    assert_equal [finding], error.findings
  end

  def test_finite_domains_preserve_primitive_kinds_and_freeze_deeply
    specs = SpecProof.load([fixture("finite.rb")])
    values = SpecProof.plan(specs).map(&:value)

    assert_equal [nil, false, true, 1, :ro], values
    assert(values.all? { |value| value.nil? || value.frozen? })
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end
end
