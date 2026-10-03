# frozen_string_literal: true

require "digest"
require "json"

module SpecProof
  # Builds the stable machine and human report representations.
  module Report
    module_function

    def value(value)
      case value
      when NilClass then { kind: "nil", value: nil }
      when TrueClass, FalseClass then { kind: "boolean", value: value }
      when Integer then { kind: "integer", value: value.to_s }
      when Symbol then { kind: "symbol", value: value.to_s }
      when String
        raise ArgumentError, "unsupported report value String" unless Domains.supported_string?(value)

        { kind: "string", value: Domains.canonical_string(value) }
      else
        raise ArgumentError, "unsupported report value #{value.class}"
      end
    end

    def source(source)
      { path: source.path, line: source.line, kind: source.kind }
    end

    def obligation(obligation)
      if obligation.respond_to?(:inputs) && obligation.inputs
        return { id: obligation.id, target: obligation.target,
                 inputs: obligation.inputs.to_h { |name, item| [name.to_s, value(item)] },
                 reasons: obligation.reasons, sources: obligation.sources.map { |item| source(item) } }
      end

      { id: obligation.id, target: obligation.target, input: obligation.input.to_s,
        value: value(obligation.value), reasons: obligation.reasons,
        sources: obligation.sources.map { |item| source(item) } }
    end

    def digest(specifications)
      declarations = specifications.flat_map do |specification|
        specification.inputs.values.map do |input|
          partitions = input.partitions.map do |partition|
            { name: partition.name.to_s, domain: normalized_domain(partition.domain) }
          end
          partitions = partitions.sort_by { |partition| partition[:name] }
          { target: specification.target, input: input.name.to_s, domain: normalized_domain(input.domain),
            exhaustive: input.exhaustive, disjoint: input.disjoint,
            partitions: partitions }
        end
      end
      declarations = declarations.sort_by { |entry| [entry[:target], entry[:input]] }
      exclusions = specifications.flat_map do |specification|
        names = specification.exclusions.keys.sort_by(&:to_s).map(&:to_s)
        names.empty? ? [] : [{ target: specification.target, excluded_inputs: names }]
      end
      exclusions.sort_by! { |entry| [entry[:target], entry[:excluded_inputs]] }
      declarations.concat(exclusions)
      declarations.concat(group_declarations(specifications))
      Digest::SHA256.hexdigest(JSON.generate(declarations))
    end

    def group_declarations(specifications)
      groups = specifications.filter_map do |specification|
        group = specification.respond_to?(:combination_group) && specification.combination_group
        next unless group

        forbidden = group.forbidden.map { |rule| canonical_assignments(rule) }
        forbidden.uniq!
        forbidden.sort_by! { |assignments| JSON.generate(assignments) }
        { target: specification.target, combination_group: group.inputs.map(&:to_s), forbidden: forbidden }
      end
      groups.sort_by { |entry| entry[:target] }
    end

    def canonical_assignments(rule)
      rule.assignments.sort_by { |name, _item| name.to_s }
          .map { |name, item| [name.to_s, value(item)] }
    end

    def input_scope(specifications)
      {
        completeness_scope: "analyzed_inputs",
        input_scope: specifications.sort_by(&:target).map do |specification|
          scope = {
            target: specification.target,
            analyzed_inputs: specification.inputs.keys.sort_by(&:to_s).map(&:to_s),
            excluded_inputs: specification.exclusions.values.sort_by { |item| item.name.to_s }.map do |item|
              { name: item.name.to_s, reason: item.reason, source: source(item.source) }
            end
          }
          group = specification.respond_to?(:combination_group) && specification.combination_group
          scope[:combination_group] = { inputs: group.inputs.map(&:to_s) } if group
          scope
        end
      }
    end

    def check(specifications:, findings:, errors: [])
      envelope(kind: "check", errors: errors).merge(
        contract_digest: digest(specifications),
        scope: input_scope(specifications),
        findings: findings.map { |finding| finding_hash(finding) }
      )
    end

    def plan(specifications:, obligations:, criterion: "input-basics-v1", errors: [])
      result = envelope(kind: "plan", errors: errors).merge(
        contract_digest: digest(specifications), criterion: criterion,
        scope: input_scope(specifications),
        obligations: obligations.map { |item| obligation(item) }
      )
      if criterion == "pairwise-finite-v1"
        result[:excluded_pairs] = specifications.flat_map do |specification|
          next [] unless specification.respond_to?(:combination_group) && specification.combination_group

          space = CombinationSpace.new(specification)
          space.excluded_pairs.map do |inputs|
            { target: specification.target,
              inputs: inputs.to_h { |name, item| [name.to_s, value(item)] },
              reason: "no_allowed_completion", sources: space.sources.map { |item| source(item) } }
          end
        end
      end
      result
    end

    def envelope(kind:, errors: [])
      { schema_version: 1, specproof_version: VERSION, kind: kind, errors: errors }
    end

    def finding_hash(finding)
      if finding.respond_to?(:inputs) && finding.inputs
        return { code: finding.code.to_s, target: finding.target,
                 inputs: finding.inputs.map(&:to_s), witness: [],
                 sources: finding.sources.map { |item| source(item) } }
      end

      { code: finding.code.to_s, target: finding.target, input: finding.input.to_s,
        witness: if finding.witness.is_a?(Array)
                   finding.witness.map do |item|
                     witness_value(item)
                   end
                 else
                   witness_value(finding.witness)
                 end,
        sources: finding.sources.map { |item| source(item) } }
    end

    def finding(finding)
      if finding.respond_to?(:inputs) && finding.inputs
        names = finding.inputs.join(", ")
        return "#{finding.code} #{finding.target} / #{names} (#{finding.sources.map do |item|
          "#{item.path}:#{item.line}"
        end.join(", ")})"
      end

      "#{finding.code} #{finding.target} / #{finding.input}: #{finding.witness.inspect} (#{finding.sources.map do |item|
        "#{item.path}:#{item.line}"
      end.join(", ")})"
    end

    def human_scope(specifications)
      lines = ["Completeness scope: analyzed inputs only"]
      specifications.sort_by(&:target).each do |specification|
        group = specification.respond_to?(:combination_group) && specification.combination_group
        lines << "Pairwise group for #{specification.target}: #{group.inputs.join(", ")}" if group
        exclusions = specification.exclusions.values.sort_by { |item| item.name.to_s }
        next if exclusions.empty?

        details = exclusions.map { |item| "#{item.name} (#{item.reason})" }.join(", ")
        lines << "Excluded for #{specification.target}: #{details}"
      end
      lines.join("\n")
    end

    def human_plan(obligations, criterion: "input-basics-v1", specifications: [])
      return human_pairwise_plan(obligations, specifications) if criterion == "pairwise-finite-v1"

      rows = obligations.group_by { |item| [item.target, item.input] }.map do |(target, input), items|
        values = items.map { |item| human_value(item.value) }.join(", ")
        ["#{target} / #{input}", "Criterion: #{criterion}", "Candidates: #{values}"]
          .concat(items.map do |item|
            locations = item.sources.map { |item_source| "#{item_source.path}:#{item_source.line}" }.join(", ")
            "#{human_value(item.value)}: #{item.reasons.join("; ")}\n    #{locations}"
          end).join("\n")
      end.join("\n\n")
      [rows, human_scope(specifications)].reject(&:empty?).join("\n\n")
    end

    def human_pairwise_plan(obligations, specifications)
      rows = pairwise_plan_rows(obligations)
      excluded_count = specifications.sum do |specification|
        next 0 unless specification.respond_to?(:combination_group) && specification.combination_group

        CombinationSpace.new(specification).excluded_pairs.length
      end
      rows = "Total pair obligations: #{obligations.length}\n\n#{rows}"
      rows += "\n\nExcluded pairs: #{excluded_count}"
      [rows, human_scope(specifications)].reject(&:empty?).join("\n\n")
    end

    def pairwise_plan_rows(obligations)
      grouped_rows = obligations.group_by { |item| [item.target, item.inputs.keys.map(&:to_s)] }
      grouped_rows.map do |(target, names), items|
        lines = ["#{target} / #{names.join(" × ")}", "Criterion: pairwise-finite-v1",
                 "Pair obligations: #{items.length}"]
        items.each do |item|
          values = item.inputs.map { |name, item_value| "#{name}=#{human_value(item_value)}" }.join(", ")
          locations = item.sources.map { |item_source| "#{item_source.path}:#{item_source.line}" }.join(", ")
          lines << "#{values}: #{item.reasons.join("; ")}\n    #{locations}"
        end
        lines.join("\n")
      end.join("\n\n")
    end

    def human_value(value)
      return ":#{value}" if value.is_a?(Symbol)
      return Domains.canonical_string(value).inspect if Domains.supported_string?(value)

      value.inspect
    end

    def normalized_domain(domain)
      if domain.is_a?(IntegerDomain)
        { kind: "integer", lower: domain.lower.to_s, upper: domain.upper.to_s }
      else
        { kind: "finite", values: domain.values.map { |value| value(value) } }
      end
    end

    def witness_value(value)
      value(value)
    end
  end
end
