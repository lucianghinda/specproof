# frozen_string_literal: true

module SpecProof
  # Tracks whether planned input obligations have been observed at runtime.
  # It keeps aggregate counters and a small set of invalid-input witnesses,
  # never an event trace.
  class Coverage
    WITNESS_LIMIT = 1
    REASON_LIMIT = 20

    def initialize(obligations:, specifications:)
      @specifications = specifications.to_h { |specification| [specification.target, specification] }.freeze
      @obligations = obligations.dup.freeze
      @hits = @obligations.to_h { |obligation| [obligation.id, 0] }
      @spaces = specifications.filter_map do |specification|
        next unless specification.respond_to?(:combination_group) && specification.combination_group

        [specification.target, CombinationSpace.new(specification)]
      end.to_h.freeze
      @outside_counts = Hash.new(0)
      @outside_witnesses = Hash.new { |hash, target| hash[target] = [] }
      @outside_combination_counts = Hash.new(0)
      @outside_combination_evidence = {}
      @incomplete_reasons = Hash.new { |hash, target| hash[target] = [] }
      @observed_targets = {}
      @incomplete_targets = {}
    end

    # This command mutates coverage; its boolean reports acceptance, not state.
    def observe(target:, arguments:) # rubocop:disable Naming/PredicateMethod
      target = target.to_s
      specification = @specifications[target]
      return false unless specification

      @observed_targets[target] = true
      tuple = primitive_tuple(arguments)
      unless valid_tuple?(specification, tuple)
        record_outside(target, tuple)
        return false
      end
      space = @spaces[target]
      if space && !space.allowed?(tuple)
        record_outside(target, tuple)
        record_outside_combination(target, tuple, space.sources)
        return false
      end

      @obligations.each do |obligation|
        next unless obligation.target == target

        if obligation.respond_to?(:inputs) && obligation.inputs
          next unless obligation.inputs.all? { |name, value| tuple.fetch(name) == value }
        else
          next unless tuple.fetch(obligation.input) == obligation.value
        end

        @hits[obligation.id] += 1
      end
      true
    end

    def mark_incomplete(target:, reason:)
      target = target.to_s
      @incomplete_targets[target] = true
      reasons = @incomplete_reasons[target]
      value = primitive_string(reason)
      reasons << value if reasons.length < REASON_LIMIT && !reasons.include?(value)
      self
    end

    def missing
      to_report.fetch(:missing)
    end

    def exercised
      to_report.fetch(:exercised)
    end

    # Returns a compact projection suitable for wrapping in Report.envelope.
    def to_report
      projection = base_projection
      projection.merge!(combination_projection) unless @spaces.empty?
      projection
    end

    private

    def base_projection
      rows = obligation_rows
      exercised_rows = rows.select { |row| row.fetch(:status) == "exercised" }
      missing_rows = rows.select { |row| row.fetch(:status) == "not_observed" }
      unknown_count = rows.count { |row| row.fetch(:status) == "unknown" }
      not_observed_count = missing_rows.length
      exercised = exercised_rows.length
      incomplete_reasons = @incomplete_reasons.values.flatten.uniq
      complete = @incomplete_targets.none?
      observed = !@observed_targets.empty?
      {
        obligations: rows,
        missing: missing_rows,
        exercised: exercised_rows,
        exercised_count: exercised,
        obligation_count: rows.length,
        missing_count: missing_rows.length,
        unknown_count: unknown_count,
        not_observed_count: not_observed_count,
        completion_percent: completion_percent(rows, complete, observed, exercised),
        status: if observed
                  (complete ? "complete" : "incomplete")
                else
                  "not_observed"
                end,
        completeness: complete ? "complete" : "incomplete",
        outside_domain: outside_domain_report,
        incomplete_reasons: incomplete_reasons,
        evidence_mode: "obligation_hits",
        replay: false
      }
    end

    def obligation_rows
      @obligations.map do |obligation|
        hits = @hits.fetch(obligation.id)
        state = obligation_state(hits, obligation.target)
        Report.obligation(obligation).merge(status: state, hits: hits)
      end
    end

    def obligation_state(hits, target)
      return "exercised" if hits.positive?
      return "unknown" if @incomplete_targets[target]

      "not_observed"
    end

    def outside_domain_report
      @outside_counts.to_h do |target, count|
        witness = @outside_witnesses.fetch(target).first
        [target, { count: count, witness: typed_tuple(witness) }]
      end
    end

    def combination_projection
      {
        outside_combinations: outside_combinations_report,
        excluded_pairs: excluded_pairs_report
      }
    end

    def outside_combinations_report
      @outside_combination_counts.to_h do |target, count|
        evidence = @outside_combination_evidence.fetch(target)
        [target, { count: count, witness: typed_tuple(evidence.fetch(:witness)),
                   sources: evidence.fetch(:sources).map { |item| Report.source(item) } }]
      end
    end

    def excluded_pairs_report
      @spaces.flat_map do |target, space|
        space.excluded_pairs.map do |inputs|
          { target: target, inputs: typed_inputs(inputs), reason: "no_allowed_completion",
            sources: space.sources.map { |item| Report.source(item) } }
        end
      end
    end

    def completion_percent(rows, complete, observed, exercised)
      return if rows.empty? || !complete || !observed

      ((exercised * 100.0) / rows.length).round(2)
    end

    def valid_tuple?(specification, tuple)
      return false unless tuple

      expected = specification.inputs.keys
      return false unless tuple.keys.sort_by(&:to_s) == expected.sort_by(&:to_s)

      specification.inputs.all? do |name, input|
        Domains.include?(input.domain, tuple.fetch(name))
      end
    end

    def record_outside_combination(target, tuple, sources)
      @outside_combination_counts[target] += 1
      @outside_combination_evidence[target] ||= { witness: tuple, sources: sources.dup.freeze }.freeze
    end

    def typed_inputs(inputs)
      inputs.to_h { |name, value| [name.to_s, Report.value(value)] }
    end

    def primitive_tuple(arguments)
      return nil unless arguments.is_a?(Hash)

      arguments.each_with_object({}) do |(key, value), normalized|
        return nil unless key.is_a?(Symbol)

        name = key
        return nil unless Domains.primitive?(value)

        normalized[name] = Domains.supported_string?(value) ? Domains.canonical_string(value) : value
      rescue NoMethodError
        return nil
      end.freeze
    end

    def record_outside(target, tuple)
      @outside_counts[target] += 1
      witnesses = @outside_witnesses[target]
      witnesses << tuple if witnesses.length < WITNESS_LIMIT && !witnesses.include?(tuple)
    end

    def typed_tuple(tuple)
      return { kind: "invalid_tuple" } unless tuple

      tuple.to_h { |key, value| [key.to_s, Report.value(value)] }
    end

    def primitive_string(value)
      text = value.is_a?(String) || value.is_a?(Symbol) ? value.to_s : "incomplete collection"
      text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?").byteslice(0, 240).to_s.freeze
    end
  end
end
