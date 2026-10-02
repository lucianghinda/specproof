SpecProof.define "Example#value" do
  input :value, values: [:allowed], exhaustive: false, disjoint: true do
    partition :first, values: [:other]
    partition :second, values: %i[other extra]
  end
end
