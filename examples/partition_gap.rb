# frozen_string_literal: true

SpecProof.define "AgePolicy#adult?" do
  input :age, range: 0..120, exhaustive: true, disjoint: true do
    partition :minor, range: 0..17
    partition :adult, range: 18..64
  end
end
