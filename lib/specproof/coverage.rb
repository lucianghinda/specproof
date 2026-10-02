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
      @outside_counts = Hash.new(0)
      @outside_witnesses = Hash.new { |hash, target| hash[target] = [] }
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

      @obligations.each do |obligation|
        next unless obligation.target == target && tuple.fetch(obligation.input) == obligation.value

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
      rows = @obligations.map do |obligation|
        hits = @hits.fetch(obligation.id)
        state = if hits.positive?
                  "exercised"
                elsif @incomplete_targets[obligation.target]
                  "unknown"
                else
                  "not_observed"
                end
        Report.obligation(obligation).merge(status: state, hits: hits)
      end
      exercised = rows.count { |row| row.fetch(:status) == "exercised" }
      missing = rows.select { |row| row.fetch(:status) == "not_observed" }
      unknown = rows.select { |row| row.fetch(:status) == "unknown" }
      exercised_rows = rows.select { |row| row.fetch(:status) == "exercised" }
      not_observed = rows.select { |row| row.fetch(:status) == "not_observed" }
      incomplete_reasons = @incomplete_reasons.values.flatten.uniq
      complete = @incomplete_targets.none?
      observed = !@observed_targets.empty?
      {
        obligations: rows,
        missing: missing,
        exercised: exercised_rows,
        exercised_count: exercised,
        obligation_count: rows.length,
        missing_count: missing.length,
        unknown_count: unknown.length,
        not_observed_count: not_observed.length,
        completion_percent: completion_percent(rows, complete, observed, exercised),
        status: if observed
                  (complete ? "complete" : "incomplete")
                else
                  "not_observed"
                end,
        completeness: complete ? "complete" : "incomplete",
        outside_domain: @outside_counts.to_h do |target, count|
          witness = @outside_witnesses.fetch(target).first
          [target, { count: count, witness: typed_tuple(witness) }]
        end,
        incomplete_reasons: incomplete_reasons,
        evidence_mode: "obligation_hits",
        replay: false
      }
    end

    private

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

    def primitive_tuple(arguments)
      return nil unless arguments.is_a?(Hash)

      arguments.each_with_object({}) do |(key, value), normalized|
        return nil unless key.is_a?(Symbol)

        name = key
        return nil unless primitive?(value)

        normalized[name] = value
      rescue NoMethodError
        return nil
      end.freeze
    end

    def primitive?(value)
      case value
      when NilClass, TrueClass, FalseClass, Integer, Symbol then true
      else false
      end
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
