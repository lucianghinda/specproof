# frozen_string_literal: true

# Example age policy whose adult boundary begins at 18.
class AgePolicy
  def adult?(age)
    age >= 18
  end
end
