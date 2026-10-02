# frozen_string_literal: true

require "digest"
require "json"

module SpecProof
  # Builds deterministic input candidates from valid specifications.
  class Planner
    CRITERION = "input-basics-v1"

    def initialize(specifications, criterion: CRITERION)
      unless criterion == CRITERION
        raise ConfigurationError.new("unsupported criterion #{criterion.inspect}", code: "unknown_criterion")
      end

      @specifications = specifications
      @criterion = criterion
    end

    def obligations
      findings = Checker.new(@specifications).findings
      raise InvalidSpecificationError, findings unless findings.empty?

      candidates = {}
      @specifications.each do |specification|
        specification.inputs.each_value do |input|
          input_candidates(specification, input).each do |value, reason, source|
            key = [specification.target, input.name, value]
            candidate = (candidates[key] ||= { reasons: [], sources: [] })
            candidate[:reasons] << reason
            if source.is_a?(Array)
              candidate[:sources].concat(source)
            else
              candidate[:sources] << source
            end
          end
        end
      end
      obligations = candidates.map do |(target, input, value), details|
        id = Digest::SHA256.hexdigest(JSON.generate([target, input.to_s, Report.value(value), @criterion]))
        Obligation.new(id: id, target: target, input: input, value: value,
                       reasons: details[:reasons], sources: details[:sources])
      end
      obligations.sort_by do |obligation|
        [obligation.target, obligation.input.to_s, Domains.sort_key(obligation.value)]
      end.freeze
    end

    private

    def input_candidates(_specification, input)
      domain = input.domain
      if domain.is_a?(IntegerDomain)
        base_integer_candidates(domain).map do |value, reason|
          [value, reason, input.sources]
        end + input.partitions.flat_map { |partition| partition_candidates(partition) }
      else
        domain.values.map { |value| [value, "finite input value", input.sources] }
      end
    end

    def base_integer_candidates(domain)
      return [] if Domains.empty?(domain)

      # These are candidate tuples, so filter by the value's domain membership.
      [[domain.lower, "input lower endpoint"], [domain.lower + 1, "input lower neighbor"],
       [domain.upper - 1, "input upper neighbor"], [domain.upper, "input upper endpoint"]]
        .select { |value, _reason| domain.include?(value) } # rubocop:disable Style/HashSlice
    end

    def partition_candidates(partition)
      domain = partition.domain
      return [] unless domain.is_a?(IntegerDomain) && !Domains.empty?(domain)

      [[domain.lower, "#{partition.name} lower endpoint"], [domain.upper, "#{partition.name} upper endpoint"]]
        .map { |value, reason| [value, reason, partition.source] }
    end
  end
end
