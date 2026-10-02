SpecProof.define "Risk#tier" do
  input :score, range: 0..100, exhaustive: true, disjoint: true do
    partition :low, range: 0..25
    partition :medium, range: 26..74
    partition :high, range: 75..100
  end
end
