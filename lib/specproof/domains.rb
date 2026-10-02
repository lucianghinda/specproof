# frozen_string_literal: true

module SpecProof
  # Normalizes and compares supported input domains.
  module Domains
    module_function

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
        else
          raise ConfigurationError.new("finite values must be integers, symbols, booleans, or nil",
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
      end
    end

    def include?(domain, value)
      case domain
      when IntegerDomain then value.is_a?(Integer) && value.between?(domain.lower, domain.upper)
      when FiniteDomain
        primitive?(value) && domain.values.any? { |member| member.instance_of?(value.class) && member.eql?(value) }
      else false
      end
    end

    def primitive?(value)
      value.nil? || value.equal?(true) || value.equal?(false) || value.is_a?(Integer) || value.is_a?(Symbol)
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
