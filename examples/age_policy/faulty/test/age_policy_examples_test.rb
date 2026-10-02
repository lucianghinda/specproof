# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/age_policy"

# Shows the faulty policy passing its non-boundary examples.
class AgePolicyExamplesTest < Minitest::Test
  def test_adult_examples_without_the_boundary
    policy = AgePolicy.new

    refute policy.adult?(0)
    refute policy.adult?(1)
    refute policy.adult?(17)
    assert policy.adult?(119)
    assert policy.adult?(120)
  end
end
