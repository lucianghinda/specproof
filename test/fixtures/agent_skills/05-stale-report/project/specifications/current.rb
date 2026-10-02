SpecProof.define "Profile#label" do
  input :kind, values: %i[short long], exhaustive: true, disjoint: true do
    partition :short, values: [:short]
    partition :long, values: [:long]
  end
end
