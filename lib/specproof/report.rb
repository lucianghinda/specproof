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
      else
        raise ArgumentError, "unsupported report value #{value.class}"
      end
    end

    def source(source)
      { path: source.path, line: source.line, kind: source.kind }
    end

    def obligation(obligation)
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
      Digest::SHA256.hexdigest(JSON.generate(declarations))
    end

    def check(specifications:, findings:, errors: [])
      envelope(kind: "check", errors: errors).merge(
        contract_digest: digest(specifications),
        findings: findings.map { |finding| finding_hash(finding) }
      )
    end

    def plan(specifications:, obligations:, criterion: "input-basics-v1", errors: [])
      envelope(kind: "plan", errors: errors).merge(
        contract_digest: digest(specifications), criterion: criterion,
        obligations: obligations.map { |item| obligation(item) }
      )
    end

    def envelope(kind:, errors: [])
      { schema_version: 1, specproof_version: VERSION, kind: kind, errors: errors }
    end

    def finding_hash(finding)
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
      "#{finding.code} #{finding.target} / #{finding.input}: #{finding.witness.inspect} (#{finding.sources.map do |item|
        "#{item.path}:#{item.line}"
      end.join(", ")})"
    end

    def human_plan(obligations, criterion: "input-basics-v1")
      obligations.group_by { |item| [item.target, item.input] }.map do |(target, input), items|
        values = items.map { |item| human_value(item.value) }.join(", ")
        ["#{target} / #{input}", "Criterion: #{criterion}", "Candidates: #{values}"]
          .concat(items.map do |item|
            locations = item.sources.map { |item_source| "#{item_source.path}:#{item_source.line}" }.join(", ")
            "#{human_value(item.value)}: #{item.reasons.join("; ")}\n    #{locations}"
          end).join("\n")
      end.join("\n\n")
    end

    def human_value(value)
      value.is_a?(Symbol) ? ":#{value}" : value.inspect
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
