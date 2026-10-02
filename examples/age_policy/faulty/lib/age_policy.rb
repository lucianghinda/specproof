# frozen_string_literal: true

# Deliberately faulty implementation for the missing-boundary example.
class AgePolicy
  # Deliberately wrong: the declared adult partition begins at 18.
  def adult?(age)
    age > 18
  end
end
