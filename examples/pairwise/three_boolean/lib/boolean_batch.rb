# frozen_string_literal: true

# Returns the three finite boolean inputs as a batch result.
class BooleanBatch
  def build(first:, second:, third:)
    [first, second, third]
  end
end
