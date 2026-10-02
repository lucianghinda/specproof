# frozen_string_literal: true

# Registration example with the deliberate age-greater-than defect.
class Registration
  def eligible?(age:, consent: nil)
    age > 18 && consent == true
  end
end
