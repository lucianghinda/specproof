# frozen_string_literal: true

# Builds delivery options for requested quantities and scheduling modes.
class DeliveryOptions
  def build(quantity:)
    { quantity: quantity, package: quantity.zero? ? :empty : :parcel }
  end

  def self.build(mode:)
    { mode: mode, schedule_at_checkout: mode == :scheduled }
  end
end
