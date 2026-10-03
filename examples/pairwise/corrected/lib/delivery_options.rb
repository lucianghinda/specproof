# frozen_string_literal: true

# Builds the delivery choices from the two option flags.
class DeliveryOptions
  def build(expedited:, notify:)
    {
      speed: expedited ? :express : :standard,
      notification: notify
    }
  end
end
