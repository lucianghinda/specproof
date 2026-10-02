# frozen_string_literal: true

# Registration example with the corrected inclusive adulthood boundary.
class Registration
  def eligible?(age:, consent: nil)
    age >= 18 && consent == true
  end
end
