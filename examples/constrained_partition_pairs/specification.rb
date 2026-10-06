# frozen_string_literal: true

require "specproof"

SpecProof.define "AccountEligibility#eligible?" do
  input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end

  input :account, values: %w[personal business]
  input :country, values: %w[ro de]

  combinations :age, :account, :country do
    forbid age: in_partition(:minor), account: "business"
  end
end
