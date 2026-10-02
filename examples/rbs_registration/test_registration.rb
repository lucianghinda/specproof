# frozen_string_literal: true

require "minitest/autorun"
require "registration"
require "specproof/minitest"

REPORT = ENV.fetch("SPEC_PROOF_REPORT", "/private/tmp/specproof-registration-#{Process.pid}.json")
RBS_PATH = File.join(__dir__, "sig/registration.rbs")
SPECIFICATION = File.join(__dir__, "specification.rb")

SpecProof::Minitest.install!(
  specifications: [SPECIFICATION],
  rbs: [RBS_PATH],
  targets: ["Registration#eligible?"],
  output: REPORT,
  fail_on_missing: false
)

# Exercises only explicit RBS-backed input obligations for the example method.
class RegistrationExampleTest < Minitest::Test
  CONSENT_VALUES = [nil, false, true].freeze
  COMPLETE_AGES = [0, 1, 17, 18, 119, 120].freeze
  GAP_AGES = [0, 1, 17, 119, 120].freeze

  if ENV["CHECKPOINT"] == "boundary"
    def test_age_18_with_consent_is_eligible
      assert Registration.new.eligible?(age: 18, consent: true),
             "requirements.md: an 18-year-old who consents is eligible"
    end
  end

  def test_declared_age_and_consent_candidates_follow_the_eligibility_rule
    ages = %w[baseline boundary].include?(ENV["CHECKPOINT"]) ? GAP_AGES : COMPLETE_AGES

    ages.product(CONSENT_VALUES).each do |age, consent|
      expected = age >= 18 && consent == true
      message = "requirements.md: eligible iff age >= 18 and consent is true " \
                "(age=#{age}, consent=#{consent.inspect})"
      assert_equal expected, Registration.new.eligible?(age: age, consent: consent),
                   message
    end
  end
end
