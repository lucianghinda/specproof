# frozen_string_literal: true

require "minitest/autorun"
require_relative "delivery_policy"
require "specproof/minitest"

SpecProof::Minitest.install!(
  specifications: ["examples/input_selection/specification.rb"],
  output: "tmp/specproof-input-selection-coverage.json",
  fail_on_missing: true
)

# Exercises delivery options against the independent requirements.
class DeliveryPolicyTest < Minitest::Test
  def setup
    @policy = DeliveryPolicy.new
  end

  def test_regular_ready_delivery_is_accepted
    assert @policy.accept?({ ready: true, priority: :low }, expedited: false),
           "A regular ready delivery is accepted (requirements.md)"
  end

  def test_high_priority_expedited_delivery_is_accepted
    assert @policy.accept?({ ready: true, priority: :high }, expedited: true),
           "A high-priority expedited delivery is accepted (requirements.md)"
  end

  def test_low_priority_expedited_delivery_is_rejected
    refute @policy.accept?({ ready: true, priority: :low }, expedited: true),
           "A low-priority expedited delivery is rejected (requirements.md)"
  end

  def test_unready_delivery_is_rejected
    refute @policy.accept?({ ready: false, priority: :high }, expedited: false),
           "An unready delivery is rejected (requirements.md)"
  end
end
