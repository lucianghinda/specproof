# frozen_string_literal: true

require "specproof"

SpecProof.define "BooleanBatch#build" do
  input :first, values: [false, true]
  input :second, values: [false, true]
  input :third, values: [false, true]
  combinations :first, :second, :third, all_allowed: true
end
