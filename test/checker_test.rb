# frozen_string_literal: true

require "test_helper"
require "tempfile"

class CheckerTest < Minitest::Test
  def test_gap_and_overlap_are_reported_with_sources
    gap = SpecProof.check(SpecProof.load([fixture("age_gap.rb")])).fetch(0)
    assert_equal :partition_gap, gap.code
    assert_equal [65, 120], gap.witness
    assert_equal fixture("age_gap.rb"), gap.sources.fetch(0).path
    assert_equal 2, gap.sources.fetch(0).line
    overlap = SpecProof.check(SpecProof.load([fixture("age_overlap.rb")])).fetch(0)
    assert_equal :partition_overlap, overlap.code
    assert_equal 10, overlap.witness
    assert_equal 2, overlap.sources.size
    assert_equal [3, 4], overlap.sources.map(&:line)
  end

  def test_large_range_check_does_not_enumerate
    specs = SpecProof.load([fixture("huge.rb")])
    assert_empty SpecProof.check(specs)
  end

  def test_overlapping_partition_regions_are_reported_outside_parent_domain
    specs = SpecProof.load([fixture("outside_overlap.rb")])
    findings = SpecProof.check(specs)
    overlap = findings.find { |finding| finding.code == :partition_overlap }
    assert_equal 3, overlap.witness
    assert_equal 2, overlap.sources.size
    assert(findings.any? { |finding| finding.code == :partition_outside_domain })
  end

  def test_finite_partition_overlap_is_reported_outside_parent_domain
    specs = SpecProof.load([fixture("finite_outside_overlap.rb")])
    findings = SpecProof.check(specs)
    overlap = findings.find { |finding| finding.code == :partition_overlap }
    assert_equal :other, overlap.witness
    assert_equal 2, overlap.sources.size
    assert(findings.any? { |finding| finding.code == :partition_outside_domain })
  end

  def test_finite_gap_overlap_and_empty_semantics
    finite = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, values: [:a, :b], exhaustive: true, disjoint: true do
          partition :first, values: [:a, :outside]
          partition :second, values: [:a]
        end
      end
    RUBY
    findings = SpecProof.check(finite)
    assert_equal [:a], findings.select { |finding| finding.code == :partition_overlap }.map(&:witness)
    assert_equal [:b], findings.select { |finding| finding.code == :partition_gap }.map(&:witness)
    assert(findings.any? { |finding| finding.code == :partition_outside_domain })

    empty = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, values: [] do
          partition :empty, values: []
        end
      end
    RUBY
    assert_equal %i[empty_domain empty_partition], SpecProof.check(empty).map(&:code).sort
  end

  def test_disabled_promises_skip_gap_and_overlap_but_adjacent_intervals_are_valid
    disabled = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, range: 0..4 do
          partition :first, range: 0..2
          partition :second, range: 2..3
        end
      end
    RUBY
    refute(SpecProof.check(disabled).any? { |finding| %i[partition_gap partition_overlap].include?(finding.code) })

    adjacent = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, range: 0..5, exhaustive: true, disjoint: true do
          partition :first, range: 0..2
          partition :second, range: 3..5
        end
      end
    RUBY
    assert_empty SpecProof.check(adjacent)
  end

  def test_readable_partition_policies_control_integer_and_finite_checks
    integer = load_text(<<~RUBY)
      SpecProof.define "Example#integer" do
        input :value, range: 0..4, allow_gaps: false, allow_overlaps: true do
          partition :first, range: 0..2
          partition :second, range: 2..3
        end
      end
    RUBY
    assert_equal [:partition_gap], SpecProof.check(integer).map(&:code)

    finite = load_text(<<~RUBY)
      SpecProof.define "Example#finite" do
        input :value, values: [:a, :b], allow_gaps: true, allow_overlaps: false do
          partition :first, values: [:a, :outside]
          partition :second, values: [:a]
        end
      end
    RUBY
    findings = SpecProof.check(finite)
    assert_equal %i[partition_outside_domain partition_overlap], findings.map(&:code).sort
  end

  def test_small_integer_sweeps_match_enumerated_reference
    interval_sets = [
      [[-3, -1], [0, 3]],
      [[-3, 0], [-1, 1], [0, 3]],
      [[-4, -2], [2, 5]]
    ]
    interval_sets.each do |intervals|
      declarations = intervals.each_with_index.map do |(lower, upper), index|
        "partition :p#{index}, range: #{lower}..#{upper}"
      end.join("\n")
      source = <<~RUBY
        SpecProof.define('Example#value') { input :value, range: -3..3, exhaustive: true, disjoint: true do
        #{declarations}
        end }
      RUBY
      specs = load_text(source)
      findings = SpecProof.check(specs)
      values = (-3..3).to_a
      missing = values.reject { |value| intervals.any? { |lower, upper| value.between?(lower, upper) } }
      overlaps = intervals.each_with_index.flat_map do |left, index|
        intervals.drop(index + 1).filter_map do |right|
          witness = [left[0], right[0]].max
          witness if witness <= [left[1], right[1]].min
        end
      end
      gap_findings = findings.select do |finding|
        finding.code == :partition_gap
      end
      actual_gaps = []
      gap_findings.each do |finding|
        actual_gaps.concat((finding.witness[0]..finding.witness[1]).to_a)
      end
      actual_overlaps = findings.select { |finding| finding.code == :partition_overlap }.map(&:witness)
      assert_equal missing, actual_gaps
      assert_equal overlaps.sort, actual_overlaps.sort
    end
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def load_text(content)
    Tempfile.create(["specproof-checker", ".rb"]) do |file|
      file.write(content)
      file.flush
      return SpecProof.load([file.path])
    end
  end
end
