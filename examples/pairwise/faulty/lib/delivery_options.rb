# frozen_string_literal: true

# Builds the delivery choices with the documented interaction defect.
class DeliveryOptions
  def build(expedited:, notify:)
    {
      speed: expedited ? :express : :standard,
      notification: notify && !expedited
    }
  end
end
