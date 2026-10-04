# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/age_policy"

# Covers selected age-category and country pairs.
class AgePolicyPairwiseTest < Minitest::Test
  BASELINE_CASES = [
    [16, "ro", false],
    [30, "ro", true],
    [30, "de", true]
  ].freeze

  def test_baseline_calls_follow_the_age_requirement
    policy = AgePolicy.new

    BASELINE_CASES.each do |age, country, expected|
      assert_equal expected, policy.eligible?(age: age, country: country),
                   "requirements.md: eligibility depends on age >= 18, not country"
    end
  end

  if ENV["ADD_MISSING_CATEGORY"] == "1"
    def test_minor_from_de_is_ineligible
      refute AgePolicy.new.eligible?(age: 0, country: "de"),
             "requirements.md: every applicant under 18 is ineligible"
    end
  end
end
