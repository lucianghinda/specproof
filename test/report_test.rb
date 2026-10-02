# frozen_string_literal: true

require "test_helper"
require "json"

class ReportTest < Minitest::Test
  def test_typed_json_keeps_symbols_booleans_nil_and_large_integers_distinct
    values = [nil, false, true, :ro, 10**100].map { |value| SpecProof::Report.value(value) }
    parsed = JSON.parse(JSON.generate(values))
    assert_equal(%w[nil boolean boolean symbol integer], parsed.map { |item| item.fetch("kind") })
    assert_equal "ro", parsed[3].fetch("value")
    assert_equal (10**100).to_s, parsed[4].fetch("value")
  end

  def test_contract_digest_excludes_source_lines
    first = SpecProof.load([fixture("age_policy.rb")])
    moved = SpecProof.load([fixture("age_policy_moved.rb")])
    assert_equal SpecProof::Report.digest(first), SpecProof::Report.digest(moved)
  end

  def test_finding_witnesses_use_the_same_typed_primitive_values_as_obligations
    [nil, false, true, :ro, 10**100].each do |value|
      finding = SpecProof::Finding.new(code: :partition_gap, target: "Example#call", input: :value,
                                       witness: value, sources: [])
      assert_equal SpecProof::Report.value(value), SpecProof::Report.finding_hash(finding).fetch(:witness)
    end
    finding = SpecProof::Finding.new(code: :partition_gap, target: "Example#call", input: :value,
                                     witness: [65, 120], sources: [])
    expected = [65, 120].map { |value| SpecProof::Report.value(value) }
    assert_equal expected, SpecProof::Report.finding_hash(finding).fetch(:witness)
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end
end
