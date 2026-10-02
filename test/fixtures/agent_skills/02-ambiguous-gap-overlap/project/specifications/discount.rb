SpecProof.define "Discount#rate" do
  input :score, range: 0..100, exhaustive: true, disjoint: true do
    partition :low, range: 0..30
    partition :middle, range: 25..50
    partition :preferred, range: 60..100
  end
end
