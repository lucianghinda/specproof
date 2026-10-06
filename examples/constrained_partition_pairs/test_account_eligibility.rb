# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/account_eligibility"

# Covers selected age-category, account, and country pairs.
class AccountEligibilityPairwiseTest < Minitest::Test
  BASELINE_CASES = [
    [16, "personal", "ro", false],
    [30, "business", "ro", true],
    [30, "personal", "de", true]
  ].freeze

  def test_baseline_calls_follow_the_age_requirement
    policy = AccountEligibility.new

    BASELINE_CASES.each do |age, account, country, expected|
      assert_equal expected,
                   policy.eligible?(age: age, account: account, country: country),
                   "requirements.md: eligibility depends on age >= 18, not account or country"
    end
  end

  if ENV["ADD_MISSING_PAIRS"] == "1"
    def test_suggested_assignments_follow_the_age_requirement
      policy = AccountEligibility.new

      assert_equal false, policy.eligible?(age: 0, account: "personal", country: "de"),
                   "requirements.md: every minor is ineligible"
      assert_equal true, policy.eligible?(age: 18, account: "business", country: "de"),
                   "requirements.md: every adult with a supported account and country is eligible"
    end
  end
end
