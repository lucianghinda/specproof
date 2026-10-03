# frozen_string_literal: true

require "specproof"

SpecProof.define "DeliveryOptions#build" do
  combinations :country, :expedited, all_allowed: true
end
