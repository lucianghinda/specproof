# frozen_string_literal: true

require "specproof"

SpecProof.define "DeliveryPolicy#accept?" do
  input :expedited, values: [false, true]
  exclude_input :payload, reason: "Payload content is outside this option coverage"
end
