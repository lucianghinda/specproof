# frozen_string_literal: true

SpecProof.define "AgePolicy#adult?" do
  input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
    partition :minor, range: 0...18
    partition :adult, range: 18..120
  end
end
