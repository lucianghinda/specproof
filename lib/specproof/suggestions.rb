# frozen_string_literal: true

require "digest"
require "json"

module SpecProof
  # One allowed, unexecuted assignment selected to cover missing pairs.
  class Suggestion
    attr_reader :id, :target, :inputs, :covers, :unassigned_inputs, :sources

    def initialize(id:, target:, inputs:, covers:, unassigned_inputs:, sources:) # rubocop:disable Metrics/ParameterLists
      @id = id.to_s.dup.freeze
      @target = target.to_s.dup.freeze
      @inputs = immutable_hash(inputs)
      @covers = covers.map { |item| item.to_s.dup.freeze }.sort.freeze
      @unassigned_inputs = unassigned_inputs.map(&:to_sym).sort_by(&:to_s).freeze
      @sources = sources.uniq.freeze
      freeze
    end

    private

    def immutable_hash(hash)
      hash.sort_by { |name, _value| name.to_s }.to_h do |name, value|
        [name.to_sym, value.is_a?(String) ? Domains.canonical_string(value) : value]
      end.freeze
    end
  end

  # The suggestions and the exact evidence snapshot they were derived from.
  class SuggestionResult
    attr_reader :suggestions, :contract_digest, :source_run_id, :source_tests_passed, :source_scope, :missing_count

    def initialize(suggestions:, contract_digest:, source_run_id:, source_tests_passed:, source_scope:,
                   missing_count:) # rubocop:disable Metrics/ParameterLists
      @suggestions = suggestions.dup.freeze
      @contract_digest = contract_digest.to_s.dup.freeze
      @source_run_id = source_run_id.to_s.dup.freeze
      @source_tests_passed = source_tests_passed
      @source_scope = immutable_value(source_scope)
      @missing_count = Integer(missing_count)
      freeze
    end

    private

    def immutable_value(value)
      case value
      when Hash
        value.to_h { |key, item| [immutable_value(key), immutable_value(item)] }.freeze
      when Array then value.map { |item| immutable_value(item) }.freeze
      when String then value.dup.freeze
      else value
      end
    end
  end

  # Builds a deterministic set of allowed group assignments for missing pairs.
  class Suggestions
    CRITERION = "pairwise-finite-v1"
    STRATEGY = "greedy-pairwise-v1"
    MAX_ASSIGNMENTS = 10_000
    MAX_PAIR_ROWS = 10_000
    MAX_MISSING_MEMBERSHIPS = 1_000_000

    Candidate = Struct.new(:target, :assignment, :sources, :unassigned_inputs, :missing_ids, keyword_init: true)
    private_constant :Candidate

    def initialize(specifications, report:)
      @specifications = specifications
      @report = report
    end

    def result
      preflight_limits
      findings = Checker.new(@specifications).findings
      raise InvalidSpecificationError, findings unless findings.empty?

      obligations = Planner.new(@specifications, criterion: CRITERION).obligations
      evidence = CoverageReport.new(@report, specifications: @specifications, obligations: obligations)
      missing_ids = evidence.missing_ids
      suggestions = missing_ids.empty? ? [] : select_suggestions(obligations, missing_ids)

      SuggestionResult.new(suggestions: suggestions, contract_digest: evidence.contract_digest,
                           source_run_id: evidence.run_id, source_tests_passed: evidence.tests_passed,
                           source_scope: evidence.scope_snapshot, missing_count: missing_ids.length)
    end

    private

    def preflight_limits
      assignment_total = 0
      pair_total = 0

      groups = @specifications.sort_by(&:target).map { |specification| preflight_group(specification) }
      groups.each do |group, target_assignments, target_pairs|
        assignment_total += target_assignments
        pair_total += target_pairs
        check_cumulative_limits!(assignment_total, pair_total, group)
      end
    end

    def preflight_group(specification)
      group = specification.combination_group
      unless group
        raise ConfigurationError.new("target has no combinations declaration: #{specification.target}",
                                     code: "combinations_required", source: specification.source)
      end
      if group.inputs.length < 2
        raise ConfigurationError.new("a combinations group requires at least two inputs",
                                     code: "invalid_combination_inputs", source: group.source)
      end
      sizes = group.inputs.map { |name| preflight_domain_size(specification, group, name) }
      assignments = preflight_assignment_count(sizes, group)
      pair_rows = preflight_pair_row_count(sizes, group)
      [group, assignments, pair_rows]
    end

    def preflight_assignment_count(sizes, group)
      return 0 if sizes.any?(&:zero?)

      sizes.reduce(1) do |product, size|
        next_product = product * size
        if next_product > CombinationSpace::MAX_ASSIGNMENTS
          raise ConfigurationError.new("combinations declaration has more than " \
                                       "#{CombinationSpace::MAX_ASSIGNMENTS} complete assignments; " \
                                       "limit is #{CombinationSpace::MAX_ASSIGNMENTS}",
                                       code: "combination_limit_exceeded", source: group.source)
        end
        next_product
      end
    end

    def preflight_pair_row_count(sizes, group)
      pair_rows = 0
      preceding_size_total = 0
      sizes.each do |size|
        pair_rows += preceding_size_total * size
        if pair_rows > CombinationSpace::MAX_PAIR_ROWS
          raise ConfigurationError.new("combinations declaration has more than " \
                                       "#{CombinationSpace::MAX_PAIR_ROWS} possible pair rows; " \
                                       "limit is #{CombinationSpace::MAX_PAIR_ROWS}",
                                       code: "combination_limit_exceeded", source: group.source)
        end
        preceding_size_total += size
      end
      pair_rows
    end

    def preflight_domain_size(specification, group, name)
      if specification.exclusions.key?(name)
        raise ConfigurationError.new("excluded input #{name.inspect} cannot be in a combinations group",
                                     code: "excluded_combination_input", source: group.source)
      end
      input = specification.inputs[name]
      unless input
        raise ConfigurationError.new("unknown combinations input #{name.inspect}",
                                     code: "unknown_combination_input", source: group.source)
      end
      unless input.domain.is_a?(FiniteDomain)
        raise ConfigurationError.new("combinations input #{name.inspect} must have finite values",
                                     code: "finite_combinations_required", source: input.source)
      end
      input.domain.values.length
    end

    def check_cumulative_limits!(assignments, pair_rows, group)
      return unless assignments > MAX_ASSIGNMENTS || pair_rows > MAX_PAIR_ROWS

      raise ConfigurationError.new("pairwise suggestions exceed the cumulative combination space limit",
                                   code: "suggestion_limit_exceeded", source: group.source)
    end

    def select_suggestions(obligations, missing_ids)
      missing = missing_ids.to_h { |id| [id, true] }
      specifications = @specifications.sort_by(&:target)
      spaces = specifications.map { |specification| [specification, CombinationSpace.new(specification)] }
      missing_pair_ids = missing_pair_id_index(obligations, missing)
      candidates = []
      membership_total = 0

      # Keep the count pass separate so oversized membership lists are rejected before allocation.
      spaces.each do |specification, space|
        space.allowed_assignments.each do |assignment|
          memberships = missing_pair_count(specification.target, assignment, missing_pair_ids)
          membership_total += memberships
          if membership_total > MAX_MISSING_MEMBERSHIPS
            raise ConfigurationError.new("pairwise suggestions exceed the candidate-to-missing-pair limit",
                                         code: "suggestion_limit_exceeded")
          end
        end
      end

      spaces.each do |specification, space| # rubocop:disable Style/CombinableLoops
        group_names = specification.combination_group.inputs
        unassigned = (specification.inputs.keys - group_names + specification.exclusions.keys).uniq
        unassigned.sort_by!(&:to_s)
        space.allowed_assignments.each do |assignment|
          candidates << Candidate.new(target: specification.target, assignment: assignment,
                                      sources: space.sources, unassigned_inputs: unassigned,
                                      missing_ids: missing_ids_for(specification.target, assignment, missing_pair_ids))
        end
      end

      build_greedy_result(candidates, obligations, missing_ids)
    end

    def missing_pair_id_index(obligations, missing)
      obligations.each_with_object({}) do |obligation, index|
        next unless missing.key?(obligation.id)

        index[pair_index_key(obligation.target, obligation.inputs)] = obligation.id
      end.freeze
    end

    def pair_index_key(target, inputs)
      [target, *inputs.sort_by { |name, _value| name.to_s }.flat_map { |name, value| [name, value] }].freeze
    end

    def missing_pair_count(target, assignment, missing_pair_ids)
      count = 0
      each_input_pair(assignment.keys) do |left, right|
        pair = [[left, assignment.fetch(left)], [right, assignment.fetch(right)]]
        count += 1 if missing_pair_ids.key?(pair_index_key(target, pair))
      end
      count
    end

    def missing_ids_for(target, assignment, missing_pair_ids)
      ids = []
      each_input_pair(assignment.keys) do |left, right|
        pair = [[left, assignment.fetch(left)], [right, assignment.fetch(right)]]
        id = missing_pair_ids[pair_index_key(target, pair)]
        ids << id if id
      end
      ids.sort.freeze
    end

    def build_greedy_result(candidates, obligations, missing_ids)
      missing_lookup = missing_ids.to_h { |id| [id, true] }
      missing_by_target = obligations.select { |obligation| missing_lookup.key?(obligation.id) }
                                     .group_by(&:target)
                                     .transform_values { |items| items.map(&:id) }
      candidates.group_by(&:target).sort_by(&:first).flat_map do |target, target_candidates|
        greedy_target(target_candidates, missing_by_target.fetch(target, []))
      end.freeze
    end

    def greedy_target(candidates, missing_ids)
      candidates_by_missing = Hash.new { |hash, id| hash[id] = [] }
      scores = candidates.map.with_index do |candidate, index|
        candidate.missing_ids.each { |id| candidates_by_missing[id] << index }
        candidate.missing_ids.length
      end
      uncovered = missing_ids.to_h { |id| [id, true] }
      selected = []

      until uncovered.empty?
        best_index = nil
        best_score = 0
        scores.each_with_index do |score, index|
          next unless score > best_score

          best_index = index
          best_score = score
        end
        break unless best_index

        candidate = candidates.fetch(best_index)
        newly_covered = candidate.missing_ids.select { |id| uncovered.key?(id) }.sort
        selected << Suggestion.new(
          id: suggestion_id(candidate.target, candidate.assignment),
          target: candidate.target,
          inputs: candidate.assignment,
          covers: newly_covered,
          unassigned_inputs: candidate.unassigned_inputs,
          sources: candidate.sources
        )
        newly_covered.each do |id|
          uncovered.delete(id)
          candidates_by_missing.fetch(id, []).each { |index| scores[index] -= 1 }
        end
      end

      unless uncovered.empty?
        raise ConfigurationError.new("missing pair obligations have no allowed suggestion assignment",
                                     code: "coverage_contract_mismatch")
      end

      selected
    end

    def each_input_pair(names)
      names.each_with_index do |left, index|
        names.drop(index + 1).each { |right| yield left, right }
      end
    end

    def suggestion_id(target, assignment)
      encoded = assignment.sort_by { |name, _value| name.to_s }
                          .map { |name, value| [name.to_s, Report.value(value)] }
      Digest::SHA256.hexdigest(JSON.generate([target, encoded, CRITERION, STRATEGY]))
    end
  end
end
