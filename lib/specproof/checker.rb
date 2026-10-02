# frozen_string_literal: true

module SpecProof
  # Finds contradictions between declared domains and partitions.
  class Checker
    def initialize(specifications)
      @specifications = specifications
    end

    def findings
      results = []
      @specifications.each do |specification|
        specification.inputs.each_value do |input|
          check_input(specification, input, results)
        end
      end
      results.sort_by do |finding|
        [finding.target, finding.input.to_s, finding.code.to_s, sortable_witness(finding.witness)]
      end.freeze
    end

    private

    def check_input(specification, input, results)
      domain = input.domain
      if Domains.empty?(domain)
        results << finding(:empty_domain, specification, input, Domains.to_a(domain), input.sources)
      end
      input.partitions.each do |partition|
        if Domains.empty?(partition.domain)
          results << finding(:empty_partition, specification, input, Domains.to_a(partition.domain), [partition.source])
        else
          check_containment(specification, input, partition, results)
        end
      end
      if domain.is_a?(IntegerDomain)
        check_integer_family(specification, input, results) unless Domains.empty?(domain)
      else
        check_finite_family(specification, input, results)
      end
      check_type_domain(specification, input, results) if input.type_constraint
    end

    def check_containment(specification, input, partition, results)
      domain = input.domain
      child = partition.domain
      outside = if domain.is_a?(IntegerDomain)
                  ranges = []
                  ranges << [child.lower, [child.upper, domain.lower - 1].min] if child.lower < domain.lower
                  ranges << [[child.lower, domain.upper + 1].max, child.upper] if child.upper > domain.upper
                  ranges.reject { |left, right| left > right }
                else
                  child.values.reject { |value| domain.values.include?(value) }
                end
      return if outside.empty?

      witness = outside.first
      results << finding(:partition_outside_domain, specification, input, witness, input.sources + [partition.source])
    end

    def check_integer_family(specification, input, results)
      partitions = input.partitions.select { |part| part.domain.is_a?(IntegerDomain) && !Domains.empty?(part.domain) }
      if input.disjoint
        partitions.each_with_index do |left, index|
          partitions.drop(index + 1).each do |right|
            lower = [left.domain.lower, right.domain.lower].max
            upper = [left.domain.upper, right.domain.upper].min
            next if lower > upper

            results << finding(:partition_overlap, specification, input, lower, [left.source, right.source])
          end
        end
      end
      return unless input.exhaustive

      cursor = input.domain.lower
      partitions.map(&:domain).sort_by { |part| [part.lower, part.upper] }.each do |part|
        lower = [part.lower, input.domain.lower].max
        upper = [part.upper, input.domain.upper].min
        next if lower > upper

        results << finding(:partition_gap, specification, input, [cursor, lower - 1], input.sources) if cursor < lower
        cursor = [cursor, upper + 1].max
      end
      return unless cursor <= input.domain.upper

      results << finding(:partition_gap, specification, input, [cursor, input.domain.upper], input.sources)
    end

    def check_finite_family(specification, input, results)
      partitions = input.partitions.select { |part| part.domain.is_a?(FiniteDomain) && !part.domain.values.empty? }
      if input.disjoint
        partitions.each_with_index do |left, index|
          partitions.drop(index + 1).each do |right|
            common = left.domain.values & right.domain.values
            common.each do |value|
              results << finding(:partition_overlap, specification, input, value, [left.source, right.source])
            end
          end
        end
      end
      return unless input.exhaustive

      covered = partitions.flat_map { |part| part.domain.values }.uniq
      (input.domain.values - covered).each do |value|
        results << finding(:partition_gap, specification, input, value, input.sources)
      end
    end

    def check_type_domain(specification, input, results)
      witness = TypeConstraints.first_excluded(input.type_constraint, input.domain)
      return if witness.equal?(TypeConstraints::NO_EXCLUSION)

      results << finding(:type_domain_conflict, specification, input, witness, input.sources)
    end

    def finding(code, specification, input, witness, sources)
      Finding.new(code: code, target: specification.target, input: input.name, witness: witness, sources: sources)
    end

    def sortable_witness(witness)
      witness.is_a?(Array) ? [0, *witness] : [1, *Domains.sort_key(witness)]
    end
  end
end
