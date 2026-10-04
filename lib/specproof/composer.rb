# frozen_string_literal: true

module SpecProof
  # Combines behavioral declarations with imported scalar input constraints.
  module Composer
    module_function

    def compose(specifications:, type_facts:)
      specifications_by_target = index_specifications(specifications)
      facts_by_target = index_type_facts(type_facts)

      targets = (specifications_by_target.keys | facts_by_target.keys).sort
      targets.map do |target|
        specification = specifications_by_target[target]
        target_facts = facts_by_target.fetch(target, {})
        exclusions = specification&.exclusions || {}
        conflict = target_facts.keys & exclusions.keys
        unless conflict.empty?
          name = conflict.min_by(&:to_s)
          raise ConfigurationError.new("type fact collides with excluded input #{target} / #{name}",
                                       code: "input_exclusion_overlap", source: target_facts.fetch(name).source)
        end
        input_names = ((specification&.inputs&.keys || []) | target_facts.keys).sort_by(&:to_s)
        inputs = input_names.to_h do |name|
          [name, compose_input(target, name, specification&.inputs&.[](name), target_facts[name])]
        end
        source = specification&.source || canonical_source(target_facts.values.map(&:source))
        if inputs.empty?
          raise ConfigurationError.new(
            "target must declare at least one analyzed input: #{target}", code: "inputs_required", source: source
          )
        end
        composed = Specification.new(target: target, inputs: inputs, exclusions: exclusions,
                                     combination_group: specification&.combination_group, source: source)
        PartitionSpace.for_specification(composed, validate_geometry: false) if composed.combination_group
        composed
      end.freeze
    end

    def index_specifications(specifications)
      specifications.each_with_object({}) do |specification, index|
        previous = index[specification.target]
        next index[specification.target] = specification unless previous

        sources = [previous.source, specification.source].compact.uniq.sort_by { |source| source_key(source) }
        locations = sources.map { |source| "#{source.path}:#{source.line}" }.join(", ")
        raise ConfigurationError.new("duplicate target #{specification.target} (#{locations})",
                                     code: "duplicate_target", source: specification.source)
      end
    end
    private_class_method :index_specifications

    def index_type_facts(type_facts)
      type_facts.each_with_object(Hash.new { |targets, target| targets[target] = {} }) do |fact, index|
        target_facts = index[fact.target]
        if target_facts.key?(fact.input)
          previous = target_facts.fetch(fact.input)
          sources = [previous.source, fact.source].compact.uniq.sort_by { |source| source_key(source) }
          locations = sources.map { |source| "#{source.path}:#{source.line}" }.join(", ")
          raise ConfigurationError.new("duplicate type fact for #{fact.target} / #{fact.input} (#{locations})",
                                       code: "duplicate_type_fact", source: fact.source)
        end
        target_facts[fact.input] = fact
      end
    end
    private_class_method :index_type_facts

    def compose_input(target, name, input, fact)
      return input unless fact

      sources = [fact.source].compact.uniq.sort_by { |source| source_key(source) }
      domain = input&.domain || TypeConstraints.finite_domain(fact.constraint)
      unless domain
        source = canonical_source(sources)
        location = source ? " at #{source.path}:#{source.line}" : ""
        message = "integer input needs a finite DSL domain refinement: #{target} / #{name}#{location}"
        raise ConfigurationError.new(message, code: "domain_refinement_required", source: source)
      end

      Input.new(name: name, domain: domain, partitions: input&.partitions || [],
                exhaustive: input&.exhaustive || false, disjoint: input&.disjoint || false,
                source: input&.source || canonical_source(sources), type_constraint: fact.constraint,
                type_sources: sources)
    end
    private_class_method :compose_input

    def canonical_source(sources)
      sources.compact.min_by { |source| source_key(source) }
    end
    private_class_method :canonical_source

    def source_key(source)
      [source.path, source.line, source.kind]
    end
    private_class_method :source_key
  end
end
