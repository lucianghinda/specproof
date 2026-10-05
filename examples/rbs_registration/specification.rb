# frozen_string_literal: true

require "specproof"

SpecProof.define "Registration#eligible?" do
  input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
