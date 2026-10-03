# frozen_string_literal: true

SpecProof.define "ConstrainedPairwise#call" do
  input :a, values: [false, true]
  input :b, values: [false, true]
  combinations :a, :b do
    forbid a: true, b: false
  end
end
