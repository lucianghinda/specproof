# frozen_string_literal: true

# Applies the age requirement to supported account and country values.
class AccountEligibility
  def eligible?(age:, account:, country:)
    %w[personal business].include?(account) && %w[ro de].include?(country) && age >= 18
  end
end
