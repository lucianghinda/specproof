SpecProof.define "AgePolicy#adult?" do
  input :age, range: 0..20, allow_gaps: true, allow_overlaps: false do
    partition :lower, range: 0..10
    partition :upper, range: 10..20
  end
end
