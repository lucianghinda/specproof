# frozen_string_literal: true

# Exercises all pairs among three boolean inputs with four calls.
class BooleanBatchTest < Minitest::Test
  def setup
    @batch = BooleanBatch.new
  end

  def test_all_inputs_false
    assert_equal([false, false, false],
                 @batch.build(first: false, second: false, third: false))
  end

  def test_first_false_other_inputs_true
    assert_equal([false, true, true],
                 @batch.build(first: false, second: true, third: true))
  end

  def test_first_and_third_true
    assert_equal([true, false, true],
                 @batch.build(first: true, second: false, third: true))
  end

  def test_first_and_second_true
    assert_equal([true, true, false],
                 @batch.build(first: true, second: true, third: false))
  end
end
