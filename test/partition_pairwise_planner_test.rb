# frozen_string_literal: true

require "test_helper"
require "tempfile"

class PartitionPairwisePlannerTest < Minitest::Test
  CRITERION = "pairwise-partitions-v1"

  def test_pairwise_obligations_use_partition_categories_without_expanding_integer_ranges
    specs = load_text(<<~RUBY)
      SpecProof.define "Registration#eligible?" do
        input :age, range: 0..120, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    obligations = SpecProof.plan(specs, criterion: CRITERION)
    assert_equal 4, obligations.length
    assert_equal %i[adult minor], obligations.map { |item| item.inputs.fetch(:age).name }.uniq.sort
    assert_equal [0, 18], obligations.map { |item| item.inputs.fetch(:age).lower }.uniq.sort
    assert(obligations.all? { |item| item.inputs.fetch(:age).frozen? })
    assert_equal 4, obligations.map(&:id).uniq.length
    assert_equal obligations.map(&:id).sort,
                 SpecProof.plan(load_text(<<~RUBY), criterion: CRITERION).map(&:id).sort
                   SpecProof.define "Registration#eligible?" do
                     input :country, values: [:de, :ro]
                     input :age, range: 0..120, exhaustive: true, disjoint: true do
                       partition :adult, range: 18..120
                       partition :minor, range: 0...18
                     end
                     combinations :country, :age, all_allowed: true
                   end
                 RUBY
  end

  def test_readable_partition_policies_preserve_legacy_digests_and_obligation_ids
    legacy = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#compatible" do
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    readable = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#compatible" do
        input :age, range: 0..20, allow_gaps: false, allow_overlaps: false do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    assert_equal SpecProof::Report.digest(legacy), SpecProof::Report.digest(readable)
    assert_equal SpecProof.plan(legacy, criterion: CRITERION).map(&:id),
                 SpecProof.plan(readable, criterion: CRITERION).map(&:id)
  end

  def test_partition_levels_have_value_equality_and_integer_membership
    level = SpecProof::PartitionLevel.new(name: :minor, lower: 0, upper: 17)

    assert_equal level, SpecProof::PartitionLevel.new(name: :minor, lower: 0, upper: 17)
    assert_equal level.hash, SpecProof::PartitionLevel.new(name: :minor, lower: 0, upper: 17).hash
    assert(level.include?(0))
    assert(level.include?(17))
    refute(level.include?(18))
    refute(level.include?("17"))
    assert_equal 0, level.representative
    assert(level.frozen?)
    assert_raises(NoMethodError) { level.name = :adult }
  end

  def test_partition_space_keeps_huge_integer_bounds_as_categories
    huge = 10**100
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#huge" do
        input :number, range: -#{huge}..#{huge}, exhaustive: true, disjoint: true do
          partition :negative, range: -#{huge}..-1
          partition :nonnegative, range: 0..#{huge}
        end
        input :kind, values: [:one, :two]
        combinations :number, :kind, all_allowed: true
      end
    RUBY

    space = SpecProof::PartitionSpace.new(specs.first)
    assert_equal 4, space.allowed_count
    assert_equal 4, space.pairs.length
    assert(space.pairs.flat_map(&:values).any?(SpecProof::PartitionLevel))
    assert(space.allowed?({ number: huge, kind: :one }))
    refute(space.allowed?({ number: huge + 1, kind: :one }))
  end

  def test_normal_loading_accepts_valid_partition_groups
    specs = load_text(<<~RUBY, allow_exclusion_only: false)
      SpecProof.define "Example#loaded" do
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    assert_empty SpecProof.check(specs)
    assert_equal 4, SpecProof.plan(specs, criterion: CRITERION).length
  end

  def test_partition_level_serialization_has_stable_category_identity
    level = SpecProof::PartitionLevel.new(name: :minor, lower: 0, upper: 17)

    assert_equal({ kind: "partition", name: "minor", lower: "0", upper: "17" }, SpecProof::Report.value(level))
  end

  def test_scalar_planning_keeps_exact_integer_obligations_with_partitioned_groups
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#age" do
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    obligations = SpecProof.plan(specs)
    assert(obligations.all?(SpecProof::Obligation))
    assert_equal [0, 1, 17, 18, 19, 20], obligations.select { |item| item.input == :age }.map(&:value).uniq.sort
  end

  def test_integer_group_geometry_remains_a_semantic_finding
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#gap" do
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 19..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    assert_equal [:partition_gap], SpecProof.check(specs).map(&:code)
    error = assert_raises(SpecProof::InvalidSpecificationError) do
      SpecProof.plan(specs, criterion: CRITERION)
    end
    assert_equal [:partition_gap], error.findings.map(&:code)
    assert_raises(SpecProof::InvalidSpecificationError) { SpecProof::PartitionSpace.new(specs.first) }
  end

  def test_overlap_outside_and_empty_partition_geometry_findings_remain_explainable
    declarations = {
      overlap: <<~RUBY,
        partition :minor, range: 0..18
        partition :adult, range: 18..20
      RUBY
      outside: <<~RUBY,
        partition :minor, range: -1..17
        partition :adult, range: 18..20
      RUBY
      empty: <<~RUBY
        partition :empty, range: 1..0
        partition :all, range: 0..20
      RUBY
    }

    expected = { overlap: :partition_overlap, outside: :partition_outside_domain, empty: :empty_partition }
    declarations.each do |kind, partitions|
      specs = load_text(<<~RUBY)
        SpecProof.define "Example##{kind}" do
          input :age, range: 0..20, exhaustive: true, disjoint: true do
            #{partitions}
          end
          input :country, values: [:ro, :de]
          combinations :age, :country, all_allowed: true
        end
      RUBY

      assert_includes SpecProof.check(specs).map(&:code), expected.fetch(kind)
      error = assert_raises(SpecProof::InvalidSpecificationError) do
        SpecProof.plan(specs, criterion: CRITERION)
      end
      assert_includes error.findings.map(&:code), expected.fetch(kind)
    end
  end

  def test_new_criterion_requires_complete_disjoint_integer_partitions
    ["input :age, range: 0..20",
     "input :age, range: 0..20 do\n  partition :minor, range: 0..20\nend"].each do |input_declaration|
      specs = load_text(<<~RUBY)
        SpecProof.define "Example#missing" do
          #{input_declaration}
          input :country, values: [:ro, :de]
          combinations :age, :country, all_allowed: true
        end
      RUBY
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.plan(specs, criterion: CRITERION)
      end
      assert_equal "partition_policy_required", error.code
      assert_includes error.message, "allow_gaps: false"
      assert_includes error.message, "allow_overlaps: false"
    end
  end

  def test_new_criterion_rejects_finite_partitions_and_forbidden_assignments
    declarations = [
      <<~RUBY,
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de], exhaustive: true, disjoint: true do
          partition :local, values: [:ro]
          partition :foreign, values: [:de]
        end
        combinations :age, :country, all_allowed: true
      RUBY
      <<~RUBY
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country do
          forbid country: :de
        end
      RUBY
    ]

    declarations.each do |body|
      specs = load_text("SpecProof.define \"Example#invalid\" do\n#{body}end\n")
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.plan(specs, criterion: CRITERION)
      end
      assert_includes %w[finite_partitions_unsupported invalid_combinations_mode], error.code
    end
  end

  def test_existing_finite_criterion_still_rejects_integer_group_inputs
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#legacy" do
        input :age, range: 0..20, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..20
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.plan(specs, criterion: "pairwise-finite-v1")
    end
    assert_equal "finite_combinations_required", error.code
  end

  def test_finite_inputs_remain_typed_singleton_values
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#typed" do
        input :choice, values: [:ready, "ready"]
        input :region, values: [1]
        combinations :choice, :region, all_allowed: true
      end
    RUBY

    obligations = SpecProof.plan(specs, criterion: CRITERION)
    values = obligations.map { |item| item.inputs.fetch(:choice) }
    assert_equal [:ready, "ready"], values
    assert_equal %w[string symbol], values.map { |value| SpecProof::Report.value(value).fetch(:kind) }.sort
  end

  def test_singleton_partition_is_one_category_and_category_changes_change_pair_ids
    first = load_text(<<~RUBY)
      SpecProof.define "Example#singleton" do
        input :age, range: 18..18, exhaustive: true, disjoint: true do
          partition :adult, range: 18..18
        end
        input :country, values: [:ro]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    renamed = load_text(<<~RUBY)
      SpecProof.define "Example#singleton" do
        input :age, range: 18..18, exhaustive: true, disjoint: true do
          partition :only, range: 18..18
        end
        input :country, values: [:ro]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    adjusted = load_text(<<~RUBY)
      SpecProof.define "Example#singleton" do
        input :age, range: 18..19, exhaustive: true, disjoint: true do
          partition :adult, range: 18..19
        end
        input :country, values: [:ro]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    first_ids = SpecProof.plan(first, criterion: CRITERION).map(&:id)
    assert_equal 1, first_ids.length
    refute_equal first_ids, SpecProof.plan(renamed, criterion: CRITERION).map(&:id)
    refute_equal first_ids, SpecProof.plan(adjusted, criterion: CRITERION).map(&:id)
  end

  private

  def load_text(content, allow_exclusion_only: true)
    Tempfile.create(["specproof-partitions", ".rb"]) do |file|
      file.write(content)
      file.flush
      return SpecProof::Loader.load([file.path], allow_exclusion_only: allow_exclusion_only)
    end
  end
end
