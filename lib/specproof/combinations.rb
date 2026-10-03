# frozen_string_literal: true

module SpecProof
  # Collects static partial assignments declared in a combinations block.
  class CombinationBuilder
    attr_reader :forbidden

    def initialize(names, source)
      @names = names.freeze
      @source = source
      @forbidden = []
    end

    def forbid(**assignments)
      source = Loader.call_source
      if assignments.empty?
        raise ConfigurationError.new("forbid requires at least one assignment", code: "empty_forbidden_assignment",
                                                                                source: source || @source)
      end
      unknown = assignments.keys - @names
      unless unknown.empty?
        raise ConfigurationError.new("forbidden assignment names non-group input #{unknown.first.inspect}",
                                     code: "unknown_forbidden_input", source: source || @source)
      end
      unless assignments.values.all? { |value| Domains.primitive?(value) }
        raise ConfigurationError.new("forbidden values must be integers, symbols, strings, booleans, or nil",
                                     code: "unsupported_value", source: source || @source)
      end

      forbidden << ForbiddenAssignment.new(assignments: assignments, source: source || @source)
    end
  end

  # Enumerates a bounded finite joint domain and the pair rows it permits.
  class CombinationSpace
    MAX_ASSIGNMENTS = 10_000
    MAX_PAIR_ROWS = 10_000

    attr_reader :pairs, :excluded_pairs, :allowed_count, :sources

    def initialize(specification)
      @specification = specification
      @group = specification.combination_group
      unless @group
        raise ConfigurationError.new("target has no combinations declaration: #{specification.target}",
                                     code: "combinations_required", source: specification.source)
      end

      validate_group
      check_limits
      enumerate
    end

    def allowed?(arguments)
      normalized = arguments.each_with_object({}) do |(name, value), values|
        values[name.to_sym] = canonical_value(value)
      end
      return false unless @group.inputs.all? do |name|
        normalized.key?(name) && Domains.include?(@inputs.fetch(name).domain, normalized.fetch(name))
      end

      @group.forbidden.none? do |rule|
        rule.assignments.all? do |name, value|
          normalized.key?(name) && same_value?(normalized.fetch(name), value)
        end
      end
    end

    def allowed_assignments
      @allowed_assignments ||= canonical_allowed_assignments
    end

    private

    def validate_group
      if @group.inputs.length < 2
        raise ConfigurationError.new("a combinations group requires at least two inputs",
                                     code: "invalid_combination_inputs", source: @group.source)
      end

      @inputs = group_inputs.freeze
      validate_forbidden_assignments
      collect_sources
    end

    def group_inputs
      @group.inputs.to_h do |name|
        input = @specification.inputs[name]
        if @specification.exclusions.key?(name)
          raise ConfigurationError.new("excluded input #{name.inspect} cannot be in a combinations group",
                                       code: "excluded_combination_input", source: @group.source)
        end
        unless input
          raise ConfigurationError.new("unknown combinations input #{name.inspect}",
                                       code: "unknown_combination_input", source: @group.source)
        end
        unless input.domain.is_a?(FiniteDomain)
          raise ConfigurationError.new("combinations input #{name.inspect} must have finite values",
                                       code: "finite_combinations_required", source: input.source)
        end
        [name, input]
      end
    end

    def validate_forbidden_assignments
      @group.forbidden.each do |rule|
        if rule.assignments.empty?
          raise ConfigurationError.new("forbid requires at least one assignment",
                                       code: "empty_forbidden_assignment", source: rule.source)
        end
        rule.assignments.each do |name, value|
          input = @inputs[name]
          unless input
            raise ConfigurationError.new("forbidden assignment names non-group input #{name.inspect}",
                                         code: "unknown_forbidden_input", source: rule.source)
          end
          unless Domains.primitive?(value) && Domains.include?(input.domain, value)
            raise ConfigurationError.new("forbidden value #{value.inspect} is outside #{name.inspect}'s finite domain",
                                         code: "invalid_combination_value", source: rule.source)
          end
        end
      end
    end

    def collect_sources
      @sources = ([@group.source] + @inputs.values.flat_map(&:sources) + @group.forbidden.map(&:source))
                 .compact.uniq.sort_by { |source| [source.path, source.line, source.kind] }.freeze
    end

    def check_limits
      assignment_count = @inputs.values.reduce(1) { |count, input| count * input.domain.values.length }
      raise limit_error("complete assignments", assignment_count, @group.source) if assignment_count > MAX_ASSIGNMENTS

      pair_rows = 0
      @group.inputs.each_with_index do |left, index|
        @group.inputs.drop(index + 1).each do |right|
          pair_rows += @inputs.fetch(left).domain.values.length * @inputs.fetch(right).domain.values.length
          raise limit_error("possible pair rows", pair_rows, @group.source) if pair_rows > MAX_PAIR_ROWS
        end
      end
    end

    def limit_error(kind, count, source)
      ConfigurationError.new("combinations declaration has #{count} #{kind}; limit is #{MAX_ASSIGNMENTS}",
                             code: "combination_limit_exceeded", source: source)
    end

    def enumerate
      allowed = canonical_allowed_assignments
      @allowed_count = allowed.length
      pair_rows = {}
      allowed.each do |assignment|
        each_input_pair do |left, right|
          row = { left => assignment.fetch(left), right => assignment.fetch(right) }.freeze
          pair_rows[pair_key(row)] ||= row
        end
      end
      @pairs = pair_rows.values.sort_by { |row| row_key(row) }.freeze
      all_rows = []
      each_input_pair do |left, right|
        left_values = @inputs.fetch(left).domain.values
        right_values = @inputs.fetch(right).domain.values
        left_values.each do |left_value|
          right_values.each do |right_value|
            all_rows << { left => left_value, right => right_value }.freeze
          end
        end
      end
      feasible_keys = pair_rows.keys.to_h { |key| [key, true] }
      @excluded_pairs = all_rows.reject { |row| feasible_keys.key?(pair_key(row)) }
                                .sort_by { |row| row_key(row) }.freeze
    end

    def canonical_allowed_assignments
      complete_assignments.select { |assignment| allowed?(assignment) }.map(&:freeze).freeze
    end

    def complete_assignments
      return [] if @group.inputs.any? { |name| @inputs.fetch(name).domain.values.empty? }

      rows = [{}]
      @group.inputs.sort_by(&:to_s).each do |name|
        rows = rows.flat_map do |row|
          @inputs.fetch(name).domain.values.map { |value| row.merge(name => value) }
        end
      end
      rows
    end

    def each_input_pair
      @group.inputs.each_with_index do |left, index|
        @group.inputs.drop(index + 1).each { |right| yield left, right }
      end
    end

    def pair_key(row)
      row.map { |name, value| [name.to_s, Report.value(value)] }
    end

    def row_key(row)
      row.flat_map { |name, value| [name.to_s, Domains.sort_key(value)] }
    end

    def canonical_value(value)
      Domains.supported_string?(value) ? Domains.canonical_string(value) : value
    end

    def same_value?(left, right)
      left.instance_of?(right.class) && left.eql?(right)
    end
  end
end
