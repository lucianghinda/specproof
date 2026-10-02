# frozen_string_literal: true

require "test_helper"

class DomainsTest < Minitest::Test
  def test_integer_range_normalization_and_empty_bounds
    domain = SpecProof::IntegerDomain.from_range(0...18)
    assert_equal [0, 17], [domain.lower, domain.upper]
    assert domain.include?(17)
    refute domain.include?(18)
    empty = SpecProof::IntegerDomain.from_range(4...4)
    assert_equal [4, 3], [empty.lower, empty.upper]
    refute empty.include?(4)
  end

  def test_finite_domain_tagged_values_are_deduplicated_and_canonical
    domain = SpecProof::FiniteDomain.new([:ro, true, 1, false, nil, 1])
    assert_equal [nil, false, true, 1, :ro], domain.values
    assert domain.frozen?
    assert domain.values.frozen?
  end

  def test_large_bounds_are_supported
    value = 10**100
    domain = SpecProof::IntegerDomain.from_range(0..value)
    assert domain.include?(value)
  end

  def test_finite_membership_uses_tagged_primitive_identity
    domain = SpecProof::FiniteDomain.new([1])
    assert domain.include?(1)
    refute domain.include?(1.0)

    hostile = Object.new
    def hostile.==(_other)
      raise "equality should not be called for unsupported values"
    end
    refute domain.include?(hostile)
  end

  def test_finite_domain_rejects_unsupported_values
    assert_raises(ArgumentError) { SpecProof::FiniteDomain.new(["text"]) }
  end
end
