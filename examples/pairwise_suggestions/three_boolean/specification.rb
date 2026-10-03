# frozen_string_literal: true

require "specproof"

SpecProof.define "SuggestedBooleanBatch#build" do
  input :first, values: [false, true]
  input :second, values: [false, true]
  input :third, values: [false, true]
  exclude_input :context, reason: "Context behavior is outside this boolean interaction example"
  combinations :first, :second, :third, all_allowed: true
end
