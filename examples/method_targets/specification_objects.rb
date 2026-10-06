# frozen_string_literal: true

require "specproof"
require_relative "lib/delivery_options"
require_relative "lib/delivery_defaults"

SpecProof.define DeliveryOptions.instance_method(:build) do
  input :quantity, range: 0..100
end

SpecProof.define DeliveryOptions.method(:build) do
  input :mode, values: %i[immediate scheduled]
end

SpecProof.define DeliveryDefaults.method(:build) do
  input :region, values: %i[local remote]
end
