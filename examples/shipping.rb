# frozen_string_literal: true

SpecProof.define "Shipping#available?" do
  input :country, values: %i[ca gb us], allow_gaps: false, allow_overlaps: false do
    partition :supported, values: %i[ca gb us]
  end

  input :expedited, values: [false, true] do
    partition :standard, values: [false]
    partition :express, values: [true]
  end
end
