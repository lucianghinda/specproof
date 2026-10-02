# frozen_string_literal: true

require "test_helper"

class RegistrationTest < Minitest::Test
  def test_minor_boundary_candidates
    assert_obligation(0, false)
    assert_obligation(1, false)
    assert_obligation(17, false)
  end

  def test_adult_upper_boundary_candidates
    assert_obligation(119, true)
    assert_obligation(120, true)
  end

  private

  def assert_obligation(age, expected)
    obligation = SpecProof.plan(SpecProof.load(specifications)).find do |candidate|
      candidate.target == "Registration#adult?" && candidate.input == :age && candidate.value == age
    end
    refute_nil obligation, "missing input obligation for Registration#adult?(age: #{age})"
    assert_equal expected, Registration.new.adult?(age),
                 "SpecProof obligation #{obligation.id}; requirement: requirements.md (age >= 18 is adult); " \
                 "method: registration.rb#adult? (age=#{age})"
  end

  def specifications
    [File.expand_path("../specifications/registration.rb", __dir__)]
  end
end
