# frozen_string_literal: true

# Applies the minimum age requirement to supported countries.
class AgePolicy
  def eligible?(age:, country:)
    %w[ro de].include?(country) && age >= 18
  end
end
