# frozen_string_literal: true

module SpecProof
  ScalarTypeConstraint = Struct.new(:integer_any, :values, keyword_init: true) do # rubocop:disable Lint/StructNewOverride
    def initialize(integer_any:, values:)
      unless integer_any.equal?(true) || integer_any.equal?(false)
        raise ArgumentError, "integer_any must be true or false"
      end
      unless values.is_a?(Array) && values.all? { |value| Domains.primitive?(value) }
        raise ArgumentError, "scalar type values must be integers, symbols, booleans, or nil"
      end

      normalized = Domains.from_values(values).values
      normalized = normalized.grep_v(Integer) if integer_any
      super(integer_any: integer_any, values: normalized.freeze)
      freeze
    end
  end

  # Operations over the deliberately closed set of scalar type constraints.
  module TypeConstraints
    NO_EXCLUSION = Object.new.freeze

    module_function

    def include?(constraint, value)
      return true if constraint.integer_any && value.is_a?(Integer)
      return false unless Domains.primitive?(value)

      constraint.values.any? { |member| member.instance_of?(value.class) && member.eql?(value) }
    end

    def finite_domain(constraint)
      return nil if constraint.integer_any

      FiniteDomain.new(values: constraint.values)
    end

    def first_excluded(constraint, domain)
      return NO_EXCLUSION if Domains.empty?(domain)

      if domain.is_a?(FiniteDomain)
        domain_members = domain.values
        domain_members.each { |value| return value unless include?(constraint, value) }
        NO_EXCLUSION
      elsif domain.is_a?(IntegerDomain)
        return NO_EXCLUSION if constraint.integer_any

        first_excluded_integer(constraint, domain)
      else
        NO_EXCLUSION
      end
    end

    def union(constraints)
      constraints = constraints.to_a
      ScalarTypeConstraint.new(integer_any: constraints.any?(&:integer_any),
                               values: constraints.flat_map(&:values))
    end

    def first_excluded_integer(constraint, domain)
      cursor = domain.lower
      declared_values = constraint.values
      declared_values.each do |value|
        next unless value.is_a?(Integer) && value >= cursor
        return cursor if value > cursor

        cursor += 1
        return NO_EXCLUSION if cursor > domain.upper
      end
      cursor <= domain.upper ? cursor : NO_EXCLUSION
    end
    private_class_method :first_excluded_integer
  end
end
