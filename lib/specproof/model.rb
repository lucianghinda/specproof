# frozen_string_literal: true

module SpecProof
  Source = Struct.new(:path, :line, :kind, keyword_init: true) do
    def initialize(path:, line:, kind: "dsl")
      super(path: path.to_s.dup.freeze, line: Integer(line), kind: kind.to_s.dup.freeze)
      freeze
    end
  end

  IntegerDomain = Struct.new(:lower, :upper, keyword_init: true) do
    def initialize(lower:, upper:)
      super(lower: Integer(lower), upper: Integer(upper))
      freeze
    end
  end

  # `values` is the stable domain record field and intentionally shadows Struct#values.
  FiniteDomain = Struct.new(:values, keyword_init: true) do # rubocop:disable Lint/StructNewOverride
    def initialize(positional_values = nil, values: positional_values)
      unless values.is_a?(Array) && values.all? do |value|
        value.nil? || value.equal?(true) || value.equal?(false) || value.is_a?(Integer) || value.is_a?(Symbol)
      end
        raise ArgumentError, "finite domain values must be integers, symbols, booleans, or nil"
      end

      copied = values.uniq.sort_by { |value| Domains.sort_key(value) }.freeze
      super(values: copied)
      freeze
    end
  end

  Partition = Struct.new(:name, :domain, :source, keyword_init: true) do
    def initialize(name:, domain:, source:)
      super(name: name.to_sym, domain: domain, source: source)
      freeze
    end
  end

  Input = Struct.new(:name, :domain, :partitions, :exhaustive, :disjoint, :source,
                     :type_constraint, :type_sources, keyword_init: true) do
    def initialize(name:, domain:, partitions:, exhaustive:, disjoint:, source:, type_constraint: nil, type_sources: []) # rubocop:disable Metrics/ParameterLists
      super(name: name.to_sym, domain: domain, partitions: partitions.dup.freeze,
            exhaustive: exhaustive, disjoint: disjoint, source: source, type_constraint: type_constraint,
            type_sources: type_sources.dup.freeze)
      freeze
    end

    def sources
      ([source] + type_sources).compact.uniq.sort_by { |item| [item.path, item.line, item.kind] }.freeze
    end
  end

  Exclusion = Struct.new(:name, :reason, :source, keyword_init: true) do
    def initialize(name:, reason:, source:)
      super(name: name.to_sym, reason: reason.dup.freeze, source: source)
      freeze
    end
  end

  InputTypeFact = Struct.new(:target, :input, :constraint, :source, keyword_init: true) do
    def initialize(target:, input:, constraint:, source:)
      super(target: target.to_s.dup.freeze, input: input.to_sym, constraint: constraint, source: source)
      freeze
    end
  end

  Specification = Struct.new(:target, :inputs, :source, :exclusions, keyword_init: true) do
    def initialize(target:, inputs:, source:, exclusions: {})
      super(target: target.to_s.dup.freeze, inputs: inputs.dup.freeze, source: source,
            exclusions: exclusions.dup.freeze)
      freeze
    end
  end

  Finding = Struct.new(:code, :target, :input, :witness, :sources, keyword_init: true) do
    def initialize(code:, target:, input:, witness:, sources:)
      super(code: code.to_sym, target: target.to_s.dup.freeze, input: input.to_sym,
            witness: freeze_value(witness), sources: sources.uniq.freeze)
      freeze
    end

    private

    def freeze_value(value)
      case value
      when Array then value.map { |item| freeze_value(item) }.freeze
      when String then value.dup.freeze
      else value
      end
    end
  end

  Obligation = Struct.new(:id, :target, :input, :value, :reasons, :sources, keyword_init: true) do
    def initialize(id:, target:, input:, value:, reasons:, sources:)
      copy = value.is_a?(String) ? value.dup.freeze : value
      super(id: id.to_s.dup.freeze, target: target.to_s.dup.freeze, input: input.to_sym,
            value: copy, reasons: reasons.map { |reason| reason.to_s.dup.freeze }.uniq.freeze,
            sources: sources.uniq.freeze)
      freeze
    end
  end
end
