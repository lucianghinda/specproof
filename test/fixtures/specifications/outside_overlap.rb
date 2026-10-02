SpecProof.define "Example#value" do
  input :number, range: 0..1, exhaustive: false, disjoint: true do
    partition :first, range: 3..4
    partition :second, range: 3..5
  end
end
