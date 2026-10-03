# frozen_string_literal: true

require "test_helper"
require "json"

class ReportTest < Minitest::Test
  def test_typed_json_keeps_symbols_booleans_nil_and_large_integers_distinct
    values = [nil, false, true, :ro, "ro", 10**100].map { |value| SpecProof::Report.value(value) }
    parsed = JSON.parse(JSON.generate(values))
    assert_equal(%w[nil boolean boolean symbol string integer], parsed.map { |item| item.fetch("kind") })
    assert_equal "ro", parsed[3].fetch("value")
    assert_equal "ro", parsed[4].fetch("value")
    assert_equal (10**100).to_s, parsed[5].fetch("value")
  end

  def test_contract_digest_excludes_source_lines
    first = SpecProof.load([fixture("age_policy.rb")])
    moved = SpecProof.load([fixture("age_policy_moved.rb")])
    assert_equal SpecProof::Report.digest(first), SpecProof::Report.digest(moved)
  end

  def test_contract_digest_keeps_legacy_bytes_when_no_inputs_are_excluded
    specifications = SpecProof.load([fixture("age_policy.rb")])

    assert_equal "09fb6a2ad22d391708001e4d3367d31e3d94159549eafc2f0b387e52cb994a1f",
                 SpecProof::Report.digest(specifications)
  end

  def test_exclusion_digest_depends_on_sorted_names_but_not_reason_source_or_order
    base = SpecProof.load([fixture("age_policy.rb")]).fetch(0)
    first = with_exclusions(base, [[:payload, "Private", "a.rb", 1], [:internal, "Secret", "b.rb", 2]])
    reordered = with_exclusions(base, [[:internal, "Different", "z.rb", 90], [:payload, "Other", "y.rb", 80]])
    renamed = with_exclusions(base, [[:body, "Private", "a.rb", 1], [:internal, "Secret", "b.rb", 2]])

    assert_equal SpecProof::Report.digest([first]), SpecProof::Report.digest([reordered])
    refute_equal SpecProof::Report.digest([first]), SpecProof::Report.digest([renamed])
  end

  def test_report_scope_discloses_analyzed_and_excluded_inputs
    specification = SpecProof.load([fixture("age_policy.rb")]).fetch(0)
    scoped = with_exclusions(specification, [[:payload, "Payload outside file-ID scope", "spec.rb", 8]])

    scope = SpecProof::Report.check(specifications: [scoped], findings: []).fetch(:scope)

    assert_equal "analyzed_inputs", scope.fetch(:completeness_scope)
    assert_equal ["age"], scope.fetch(:input_scope).fetch(0).fetch(:analyzed_inputs)
    exclusion = scope.fetch(:input_scope).fetch(0).fetch(:excluded_inputs).fetch(0)
    assert_equal "Payload outside file-ID scope", exclusion.fetch(:reason)
    assert_includes SpecProof::Report.human_scope([scoped]), "payload (Payload outside file-ID scope)"
  end

  def test_finding_witnesses_use_the_same_typed_primitive_values_as_obligations
    [nil, false, true, :ro, "ro", 10**100].each do |value|
      finding = SpecProof::Finding.new(code: :partition_gap, target: "Example#call", input: :value,
                                       witness: value, sources: [])
      assert_equal SpecProof::Report.value(value), SpecProof::Report.finding_hash(finding).fetch(:witness)
    end
    finding = SpecProof::Finding.new(code: :partition_gap, target: "Example#call", input: :value,
                                     witness: [65, 120], sources: [])
    expected = [65, 120].map { |value| SpecProof::Report.value(value) }
    assert_equal expected, SpecProof::Report.finding_hash(finding).fetch(:witness)
  end

  def test_string_human_values_are_quoted_and_escaped
    assert_equal "\"a\\n\\\"b\"", SpecProof::Report.human_value("a\n\"b")
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def with_exclusions(specification, entries)
    exclusions = entries.to_h do |name, reason, path, line|
      source = SpecProof::Source.new(path: path, line: line)
      [name, SpecProof::Exclusion.new(name: name, reason: reason, source: source)]
    end
    SpecProof::Specification.new(target: specification.target, inputs: specification.inputs,
                                 source: specification.source, exclusions: exclusions)
  end
end
