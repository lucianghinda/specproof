# frozen_string_literal: true

# Verifies the single tuple observed before pairwise suggestions.
class SuggestedBooleanBatchBaselineTest < Minitest::Test
  def test_all_false_returns_the_input_values_in_order
    assert_equal([false, false, false],
                 SuggestedBooleanBatch.new.build(first: false, second: false, third: false, context: Object.new))
  end
end
