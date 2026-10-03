# frozen_string_literal: true

# Returns three finite boolean inputs as an ordered array.
class SuggestedBooleanBatch
  def build(first:, second:, third:, context:) # rubocop:disable Lint/UnusedMethodArgument
    [first, second, third]
  end
end
