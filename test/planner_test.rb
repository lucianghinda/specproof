# frozen_string_literal: true

require "test_helper"
require "tempfile"

class PlannerTest < Minitest::Test
  def test_age_candidates_and_stable_ids_when_source_moves
    first = SpecProof.plan(SpecProof.load([fixture("age_policy.rb")]))
    moved = SpecProof.plan(SpecProof.load([fixture("age_policy_moved.rb")]))
    assert_equal [0, 1, 17, 18, 119, 120], first.map(&:value)
    assert_equal first.map(&:id), moved.map(&:id)
  end

  def test_unknown_criterion_is_configuration_error
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.plan(SpecProof.load([fixture("age_policy.rb")]), criterion: "future")
    end
    assert_equal "unknown_criterion", error.code
  end

  def test_singleton_and_partition_reasons_merge_into_one_obligation
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, range: 3..3, exhaustive: true, disjoint: true do
          partition :only, range: 3..3
        end
      end
    RUBY
    obligations = SpecProof.plan(specs)
    assert_equal [3], obligations.map(&:value)
    assert_equal 1, obligations.size
    assert_includes obligations.first.reasons, "input lower endpoint"
    assert_includes obligations.first.reasons, "only upper endpoint"
    assert_equal 2, obligations.first.sources.size
  end

  def test_invalid_specifications_raise_with_all_findings
    specs = SpecProof.load([fixture("age_gap.rb")])
    error = assert_raises(SpecProof::InvalidSpecificationError) { SpecProof.plan(specs) }
    assert_equal [:partition_gap], error.findings.map(&:code)
    assert error.findings.frozen?
  end

  def test_finite_values_make_one_typed_obligation_each
    obligations = SpecProof.plan(SpecProof.load([fixture("finite.rb")]))
    assert_equal [nil, false, true, 1, :ro], obligations.map(&:value)
    assert_equal 5, obligations.map(&:value).uniq.length
    assert_equal 5, obligations.map(&:id).uniq.length
    assert(obligations.all? { |obligation| obligation.reasons == obligation.reasons.uniq })
  end

  def test_finite_strings_partition_and_plan_with_string_symbol_identity
    specs = load_text(<<~RUBY)
      SpecProof.define "Example#value" do
        input :value, values: ["", :ready, "ready", "ready"], exhaustive: true, disjoint: true do
          partition :empty, values: [""]
          partition :symbol, values: [:ready]
          partition :text, values: ["ready"]
        end
      end
    RUBY

    assert_empty SpecProof.check(specs)
    first = SpecProof.plan(specs)
    second = SpecProof.plan(specs)

    assert_equal [:ready, "", "ready"], first.map(&:value)
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 3, first.map(&:id).uniq.length
    kinds = first.map { |item| SpecProof::Report.value(item.value).fetch(:kind) }
    assert_equal %w[symbol string string], kinds
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def load_text(content)
    Tempfile.create(["specproof-planner", ".rb"]) do |file|
      file.write(content)
      file.flush
      return SpecProof.load([file.path])
    end
  end
end
