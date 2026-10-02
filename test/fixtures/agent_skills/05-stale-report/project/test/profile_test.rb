# frozen_string_literal: true

require "test_helper"

class ProfileTest < Minitest::Test
  def test_short_label
    assert_obligation(:short, "Profile")
  end

  def test_long_label
    assert_obligation(:long, "A longer profile label")
  end

  private

  def assert_obligation(kind, expected)
    obligation = SpecProof.plan(SpecProof.load(specifications)).find do |candidate|
      candidate.target == "Profile#label" && candidate.input == :kind && candidate.value == kind
    end
    refute_nil obligation, "missing input obligation for Profile#label(kind: #{kind})"
    assert_equal expected, Profile.new.label(kind),
                 "SpecProof obligation #{obligation.id}; source: current.rb#label (kind=#{kind})"
  end

  def specifications
    [File.expand_path("../specifications/current.rb", __dir__)]
  end
end
