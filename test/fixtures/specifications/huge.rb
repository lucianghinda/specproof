SpecProof.define "Example#call" do
  input :number, range: 0..(10**100), exhaustive: true, disjoint: true do
    partition :all, range: 0..(10**100)
  end
end
