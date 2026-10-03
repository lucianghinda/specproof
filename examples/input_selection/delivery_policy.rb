# frozen_string_literal: true

# Evaluates whether a delivery meets its option requirements.
class DeliveryPolicy
  def accept?(payload, expedited:)
    return false unless payload.fetch(:ready)
    return true unless expedited

    payload.fetch(:priority) == :high
  end
end
