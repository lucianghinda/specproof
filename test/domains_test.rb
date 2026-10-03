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
    assert_equal ["text"], SpecProof::FiniteDomain.new(["text"]).values
    assert_raises(ArgumentError) { SpecProof::FiniteDomain.new([(+"\xFF").force_encoding(Encoding::UTF_8)]) }
  end

  def test_finite_strings_are_copied_frozen_canonical_and_sorted_after_symbols
    ascii = +"ready"
    domain = SpecProof::Domains.from_values(["z", :ready, ascii, "ready", "", "é"])

    assert_equal [:ready, "", "ready", "z", "é"], domain.values
    refute ascii.frozen?
    ascii.replace("changed")
    assert domain.include?("ready")
    refute domain.include?("changed")
    strings_are_copied = domain.values.last(4).all? { |value| value.instance_of?(String) && value.frozen? }
    assert strings_are_copied
    assert_equal Encoding::UTF_8, domain.values.last(4).first.encoding
    assert_equal Encoding::UTF_8, domain.values.last(4).last.encoding
  end

  def test_finite_strings_preserve_symbol_identity_and_match_by_exact_type
    domain = SpecProof::Domains.from_values(["ready", :ready])

    assert_equal [:ready, "ready"], domain.values
    assert domain.include?("ready")
    assert domain.include?(:ready)
    refute domain.include?("other")
    refute domain.include?(Class.new(String).new("ready"))
  end

  def test_string_snapshots_ignore_singleton_copy_and_comparison_hooks
    value = +"ready"
    def value.eql?(_other)
      raise "application comparison hook should not run"
    end

    def value.class
      raise "application class hook should not run"
    end

    domain = SpecProof::Domains.from_values([value])

    refute value.frozen?
    assert domain.include?(value)
    assert_equal ["ready"], domain.values
    assert domain.values.fetch(0).frozen?
  end

  def test_finite_strings_accept_only_valid_utf8_or_us_ascii
    ascii = (+"abc").force_encoding(Encoding::US_ASCII)
    utf8 = "é"
    invalid = (+"\xFF").force_encoding(Encoding::UTF_8)
    binary = "abc".b
    subclass = Class.new(String).new("abc")

    [ascii, utf8, "", " \0é"].each { |value| assert SpecProof::Domains.from_values([value]).include?(value) }
    [invalid, binary, subclass].each do |value|
      error = assert_raises(SpecProof::ConfigurationError) { SpecProof::Domains.from_values([value]) }
      assert_equal "unsupported_value", error.code
    end
  end
end
