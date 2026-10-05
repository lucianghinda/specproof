# frozen_string_literal: true

module SpecProof
  # Enumerates bounded pairs over finite values and declared integer categories.
  class PartitionSpace
    MAX_ASSIGNMENTS = 10_000
    MAX_PAIR_ROWS = 10_000

    attr_reader :pairs, :excluded_pairs, :allowed_count, :sources

    def self.for_specification(specification, criterion: nil, validate_geometry: true)
      group = specification.combination_group
      has_integer_input = group&.inputs&.any? do |name|
        specification.inputs[name]&.domain.is_a?(IntegerDomain)
      end
      has_partitions = group&.inputs&.any? { |name| specification.inputs[name]&.partitions&.any? }
      use_partition_space = criterion == Planner::PARTITION_PAIRWISE_CRITERION ||
                            (criterion != Planner::PAIRWISE_CRITERION && has_integer_input && has_partitions)
      return new(specification, validate_geometry: validate_geometry) if use_partition_space

      CombinationSpace.new(specification)
    end

    def initialize(specification, validate_geometry: true)
      @specification = specification
      @group = specification.combination_group
      unless @group
        raise ConfigurationError.new("target has no combinations declaration: #{specification.target}",
                                     code: "combinations_required", source: specification.source)
      end

      validate_group
      validate_partition_geometry if validate_geometry
      check_limits
      enumerate
    end

    def allowed?(arguments)
      normalized = arguments.each_with_object({}) do |(name, value), values|
        values[name.to_sym] = canonical_value(value)
      end
      return false unless @group.inputs.all? do |name|
        normalized.key?(name) && allowed_value?(name, normalized.fetch(name))
      end

      true
    end

    def allowed_assignments
      @allowed_assignments ||= complete_assignments.freeze
    end

    private

    def validate_group
      if @group.inputs.length < 2
        raise ConfigurationError.new("a combinations group requires at least two inputs",
                                     code: "invalid_combination_inputs", source: @group.source)
      end

      @inputs = group_inputs.freeze
      unless @group.forbidden.empty?
        raise ConfigurationError.new("pairwise-partitions-v1 supports only all_allowed: true",
                                     code: "invalid_combinations_mode", source: @group.forbidden.first.source)
      end
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

        if input.domain.is_a?(IntegerDomain)
          validate_integer_input(input)
        else
          validate_finite_input(input)
        end
        [name, input]
      end
    end

    def validate_integer_input(input)
      if input.partitions.empty? || !input.exhaustive || !input.disjoint
        raise ConfigurationError.new(
          "integer input needs partitions with allow_gaps: false, allow_overlaps: false",
          code: "partition_policy_required", source: input.source
        )
      end
      return if input.partitions.all? { |partition| partition.domain.is_a?(IntegerDomain) }

      raise ConfigurationError.new("integer input partitions must use integer ranges",
                                   code: "partition_domain_kind", source: input.source)
    end

    def validate_finite_input(input)
      return if input.partitions.empty?

      raise ConfigurationError.new("finite combinations input #{input.name.inspect} cannot declare partitions",
                                   code: "finite_partitions_unsupported", source: input.source)
    end

    def validate_partition_geometry
      findings = Checker.new([@specification], check_combinations: false).findings
      return if findings.empty?

      raise InvalidSpecificationError, findings
    end

    def collect_sources
      @sources = ([@group.source] + @inputs.values.flat_map(&:sources) +
                  @inputs.values.flat_map { |input| input.partitions.map(&:source) })
                 .compact.uniq.sort_by { |source| [source.path, source.line, source.kind] }.freeze
    end

    def check_limits
      assignment_count = @inputs.values.reduce(1) { |count, input| count * values_for(input).length }
      raise limit_error("complete assignments", assignment_count) if assignment_count > MAX_ASSIGNMENTS

      pair_rows = 0
      @group.inputs.each_with_index do |left, index|
        @group.inputs.drop(index + 1).each do |right|
          pair_rows += values_for(@inputs.fetch(left)).length * values_for(@inputs.fetch(right)).length
          raise limit_error("possible pair rows", pair_rows) if pair_rows > MAX_PAIR_ROWS
        end
      end
    end

    def limit_error(kind, count)
      ConfigurationError.new("combinations declaration has #{count} #{kind}; limit is #{MAX_ASSIGNMENTS}",
                             code: "combination_limit_exceeded", source: @group.source)
    end

    def enumerate
      assignments = complete_assignments
      @allowed_count = assignments.length
      pair_rows = {}
      assignments.each do |assignment|
        each_input_pair do |left, right|
          row = { left => assignment.fetch(left), right => assignment.fetch(right) }.freeze
          pair_rows[pair_key(row)] ||= row
        end
      end
      @pairs = pair_rows.values.sort_by { |row| row_key(row) }.freeze
      @excluded_pairs = [].freeze
    end

    def complete_assignments
      return [] if @group.inputs.any? { |name| values_for(@inputs.fetch(name)).empty? }

      @group.inputs.sort_by(&:to_s).reduce([{}]) do |rows, name|
        rows.flat_map do |row|
          values_for(@inputs.fetch(name)).map { |value| row.merge(name => value) }
        end
      end.map(&:freeze).freeze
    end

    def values_for(input)
      if input.domain.is_a?(IntegerDomain)
        input.partitions.map do |partition|
          PartitionLevel.new(name: partition.name, lower: partition.domain.lower, upper: partition.domain.upper)
        end.sort_by(&:sort_key)
      else
        input.domain.values
      end
    end

    def allowed_value?(name, value)
      input = @inputs.fetch(name)
      if input.domain.is_a?(IntegerDomain)
        return false unless value.instance_of?(Integer) && input.domain.include?(value)

        matching = input.partitions.select { |partition| partition.domain.include?(value) }
        matching.length == 1
      else
        Domains.include?(input.domain, value)
      end
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
      row.flat_map { |name, value| [name.to_s, sort_key(value)] }
    end

    def sort_key(value)
      value.is_a?(PartitionLevel) ? value.sort_key : Domains.sort_key(value)
    end

    def canonical_value(value)
      Domains.supported_string?(value) ? Domains.canonical_string(value) : value
    end
  end
end
