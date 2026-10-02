# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/age_policy"

# Verifies the declared age policy examples.
class AgePolicyTest < Minitest::Test
  def test_adult_boundary
    policy = AgePolicy.new

    refute policy.adult?(0)
    refute policy.adult?(1)
    refute policy.adult?(17)
    assert policy.adult?(18)
    assert policy.adult?(119)
    assert policy.adult?(120)
  end
end
