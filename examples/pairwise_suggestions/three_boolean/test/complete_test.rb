# frozen_string_literal: true

# Checks a compact covering set against the independent array requirement.
class SuggestedBooleanBatchCompleteTest < Minitest::Test
  def setup
    @batch = SuggestedBooleanBatch.new
  end

  def test_each_requirement_backed_assignment_returns_values_in_order
    [
      [false, false, false],
      [false, true, true],
      [true, false, true],
      [true, true, false]
    ].each do |values|
      first, second, third = values
      assert_equal(values,
                   @batch.build(first: first, second: second, third: third, context: Object.new),
                   "Requirement: preserve boolean input order; see requirements.md")
    end
  end
end
