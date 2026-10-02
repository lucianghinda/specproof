# frozen_string_literal: true

SpecProof.define "Calculator#call" do
  input :age, range: 0..2
  input :mode, values: %i[on off]
end
