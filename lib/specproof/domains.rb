# frozen_string_literal: true

module SpecProof
  # Normalizes and compares supported input domains.
  module Domains
    module_function

    STRING_INSTANCE_OF = Object.instance_method(:instance_of?)
    STRING_ENCODING = String.instance_method(:encoding)
    STRING_VALID_ENCODING = String.instance_method(:valid_encoding?)

    def supported_string?(value)
      return false unless STRING_INSTANCE_OF.bind_call(value, String)

      encoding = STRING_ENCODING.bind_call(value)
      [Encoding::UTF_8, Encoding::US_ASCII].include?(encoding) && STRING_VALID_ENCODING.bind_call(value)
    rescue TypeError
      false
    end

    def canonical_string(value)
      raise ArgumentError, "unsupported string value" unless supported_string?(value)

      copy = String.new(value)
      (copy.encoding == Encoding::US_ASCII ? copy.encode(Encoding::UTF_8) : copy).freeze
    end

    def from_range(range, source: nil)
      unless range.is_a?(Range) && range.begin.is_a?(Integer) && range.end.is_a?(Integer)
        raise ConfigurationError.new("range endpoints must be bounded integers", code: "invalid_range", source: source)
      end

      upper = range.exclude_end? ? range.end - 1 : range.end
      IntegerDomain.new(lower: range.begin, upper: upper)
    end

    def from_values(values, source: nil)
      unless values.is_a?(Array)
        raise ConfigurationError.new("values must be an array", code: "invalid_values", source: source)
      end

      normalized = values.map do |value|
        case value
        when NilClass, TrueClass, FalseClass, Integer then value
        when Symbol then value.to_s.freeze.to_sym
        when String
          unless supported_string?(value)
            raise ConfigurationError.new("finite string values must be valid UTF-8 or US-ASCII strings",
                                         code: "unsupported_value", source: source)
          end

          canonical_string(value)
        else
          raise ConfigurationError.new("finite values must be integers, symbols, strings, booleans, or nil",
                                       code: "unsupported_value", source: source)
        end
      end
      normalized.uniq!
      FiniteDomain.new(values: normalized.sort_by { |value| sort_key(value) })
    end

    def sort_key(value)
      case value
      when NilClass then [0]
      when FalseClass then [1, 0]
      when TrueClass then [1, 1]
      when Integer then [2, value]
      when Symbol then [3, value.to_s]
      when String then [4, value]
      end
    end

    def include?(domain, value)
      case domain
      when IntegerDomain then value.is_a?(Integer) && value.between?(domain.lower, domain.upper)
      when FiniteDomain
        return false unless primitive?(value)

        value = canonical_string(value) if supported_string?(value)
        domain.values.any? { |member| member.instance_of?(value.class) && member.eql?(value) }
      else false
      end
    end

    def primitive?(value)
      case value
      when NilClass, TrueClass, FalseClass, Integer, Symbol then true
      when String then supported_string?(value)
      else false
      end
    end

    def empty?(domain)
      domain.is_a?(IntegerDomain) ? domain.lower > domain.upper : domain.values.empty?
    end

    def same_kind?(left, right)
      (left.is_a?(IntegerDomain) && right.is_a?(IntegerDomain)) ||
        (left.is_a?(FiniteDomain) && right.is_a?(FiniteDomain))
    end

    def to_a(domain)
      domain.is_a?(IntegerDomain) ? [domain.lower, domain.upper] : domain.values
    end
  end

  # Represents an inclusive integer interval, including an empty interval.
  class IntegerDomain
    def self.from_range(range)
      Domains.from_range(range)
    end

    def include?(value)
      value.is_a?(Integer) && value.between?(lower, upper)
    end
  end

  # Represents a finite set of supported scalar values.
  class FiniteDomain
    def include?(value)
      Domains.include?(self, value)
    end
  end
end
