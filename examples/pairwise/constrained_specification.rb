# frozen_string_literal: true

require "specproof"

SpecProof.define "ConstrainedDelivery#build" do
  input :expedited, values: [false, true]
  input :notify, values: [false, true]
  combinations :expedited, :notify do
    forbid expedited: true, notify: false
  end
end
