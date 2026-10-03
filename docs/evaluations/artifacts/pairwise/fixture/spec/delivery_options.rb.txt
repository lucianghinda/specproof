# frozen_string_literal: true

require "specproof"

SpecProof.define "DeliveryOptions#build" do
  input :expedited, values: [false, true]
  input :notify, values: [false, true]
  combinations :expedited, :notify, all_allowed: true
end
