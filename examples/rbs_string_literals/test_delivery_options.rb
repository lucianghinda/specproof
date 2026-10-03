# frozen_string_literal: true

require "minitest/autorun"
require_relative "lib/delivery_options"
require "specproof/minitest"

ROOT = File.expand_path("../..", __dir__)
SPECIFICATION = File.join(__dir__, "specification.rb")
RBS_SIGNATURE = File.join(__dir__, "sig/delivery_options.rbs")
REPORT = ENV.fetch("SPEC_PROOF_REPORT", File.join(ROOT, "tmp/rbs-string-baseline.json"))

SpecProof::Minitest.install!(
  specifications: [SPECIFICATION],
  rbs: [RBS_SIGNATURE],
  targets: ["DeliveryOptions#build"],
  criterion: "pairwise-finite-v1",
  output: REPORT,
  fail_on_missing: false
)

# Exercises the RBS-backed delivery options contract.
class DeliveryOptionsExampleTest < Minitest::Test
  BASELINE_ASSIGNMENTS = [
    ["ro", false],
    ["ro", true],
    ["de", false]
  ].freeze

  def test_baseline_assignments_follow_delivery_requirement
    delivery = DeliveryOptions.new

    BASELINE_ASSIGNMENTS.each do |country, expedited|
      expected_shipping = expedited ? "express" : "standard"
      expected = "#{country}:#{expected_shipping}"
      assert_equal expected, delivery.build(country: country, expedited: expedited),
                   "requirements.md: preserve country and select shipping by expedited"
    end
  end

  if ENV["CHECK_GAP"] == "1"
    def test_suggested_de_expedited_assignment_follows_requirement
      assert_equal "de:express", DeliveryOptions.new.build(country: "de", expedited: true),
                   "requirements.md: preserve de and select express when expedited"
    end
  end
end
