# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/age_policy"

# Demonstrates how the explicit age boundary assertion catches the defect.
class AgePolicyTest < Minitest::Test
  def test_adult_examples_without_the_boundary
    policy = AgePolicy.new

    refute policy.adult?(0)
    refute policy.adult?(1)
    refute policy.adult?(17)
    assert policy.adult?(119)
    assert policy.adult?(120)
  end

  def test_explicit_boundary_requirement
    assert AgePolicy.new.adult?(18)
  end
end
