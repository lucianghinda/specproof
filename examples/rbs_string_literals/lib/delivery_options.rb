# frozen_string_literal: true

# Builds delivery labels from explicit country and shipping options.
class DeliveryOptions
  def build(country:, expedited:)
    shipping = expedited ? "express" : "standard"
    "#{country}:#{shipping}"
  end
end
