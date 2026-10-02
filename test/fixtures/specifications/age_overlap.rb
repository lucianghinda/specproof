SpecProof.define "AgePolicy#adult?" do
  input :age, range: 0..20, exhaustive: false, disjoint: true do
    partition :lower, range: 0..10
    partition :upper, range: 10..20
  end
end
