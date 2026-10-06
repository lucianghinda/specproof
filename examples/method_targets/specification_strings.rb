# frozen_string_literal: true

require "specproof"

SpecProof.define "DeliveryOptions#build" do
  input :quantity, range: 0..100
end

SpecProof.define "DeliveryOptions.build" do
  input :mode, values: %i[immediate scheduled]
end

SpecProof.define "DeliveryDefaults.build" do
  input :region, values: %i[local remote]
end
