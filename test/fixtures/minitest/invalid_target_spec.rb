# frozen_string_literal: true

SpecProof.define "MissingTarget#run" do
  input :value, values: [nil, false, true]
end
