# frozen_string_literal: true

# Provides a region-specific shipping default.
module DeliveryDefaults
  def self.build(region:)
    { carrier: region == :local ? :nearby : :national }
  end
end
