# frozen_string_literal: true

SpecProof.define "Pairwise#call" do
  input :a, values: [false, true]
  input :b, values: [false, true]
  input :c, values: [false, true]
  combinations :a, :b, :c, all_allowed: true
end
