# frozen_string_literal: true

# Loads specification files without resolving application constants.
module SpecProof
  # Builds and validates declarations while a specification file runs.
  module Loader
    # Collects the inputs declared for one target.
    class Builder
      attr_reader :target, :source, :inputs, :exclusions, :combination_group

      def initialize(target, source)
        @target = target
        @source = source
        @inputs = {}
        @exclusions = {}
        @combination_group = nil
      end

      def input(name, **options, &block)
        location = Loader.call_source
        name = valid_name(name, location, "input")
        duplicate!(inputs, name, "duplicate_input", location)
        overlap!(name, location)
        domain, form = parse_domain(options, location)
        exhaustive = flag(options, :exhaustive, location)
        disjoint = flag(options, :disjoint, location)
        unknown = options.keys - %i[range values exhaustive disjoint]
        unknown_option!(unknown.first, location) unless unknown.empty?
        partitions = []
        if block
          partition_builder = PartitionBuilder.new(domain, form)
          partition_builder.instance_eval(&block)
          partitions = partition_builder.partitions
        end
        if (exhaustive || disjoint) && partitions.empty?
          raise ConfigurationError.new("a promised partition family must not be empty", code: "empty_partition_family",
                                                                                        source: location)
        end

        inputs[name] = Input.new(name: name, domain: domain, partitions: partitions,
                                 exhaustive: exhaustive, disjoint: disjoint, source: location)
      end

      def exclude_input(name, reason:)
        location = Loader.call_source
        name = valid_name(name, location, "input")
        duplicate!(exclusions, name, "duplicate_exclusion", location)
        overlap!(name, location)
        unless reason.is_a?(String) && !reason.strip.empty?
          raise ConfigurationError.new("exclusion reason must be a non-blank String",
                                       code: "invalid_exclusion_reason", source: location)
        end

        exclusions[name] = Exclusion.new(name: name, reason: reason, source: location)
      end

      def combinations(*names, **options, &block)
        location = Loader.call_source
        if combination_group
          raise ConfigurationError.new("a target may declare only one combinations group",
                                       code: "duplicate_combinations", source: location)
        end
        unless names.length >= 2 && names.all? { |name| name.is_a?(Symbol) && !name.to_s.empty? } && names.uniq == names
          raise ConfigurationError.new("combinations requires at least two unique non-empty input symbols",
                                       code: "invalid_combination_inputs", source: location)
        end
        unknown = options.keys - [:all_allowed]
        unknown_option!(unknown.first, location) unless unknown.empty?

        forbidden = if block
                      unless options.empty?
                        raise ConfigurationError.new("forbid block cannot be combined with options",
                                                     code: "invalid_combinations_mode", source: location)
                      end
                      builder = CombinationBuilder.new(names, location)
                      builder.instance_eval(&block)
                      if builder.forbidden.empty?
                        raise ConfigurationError.new("combinations block must declare at least one forbid",
                                                     code: "empty_combinations_block", source: location)
                      end
                      builder.forbidden
                    else
                      unless options.keys == [:all_allowed] && options[:all_allowed].equal?(true)
                        raise ConfigurationError.new("declare all_allowed: true or provide a non-empty forbid block",
                                                     code: "invalid_combinations_mode", source: location)
                      end
                      []
                    end
        @combination_group = CombinationGroup.new(inputs: names, forbidden: forbidden, source: location)
      end

      private

      def parse_domain(options, source)
        has_range = options.key?(:range)
        has_values = options.key?(:values)
        if has_range == has_values
          raise ConfigurationError.new("declare exactly one of range: or values:", code: "domain_required",
                                                                                   source: source)
        end

        if has_range
          [Domains.from_range(options[:range], source: source),
           :range]
        else
          [Domains.from_values(options[:values], source: source), :values]
        end
      end

      def flag(options, key, source)
        value = options.fetch(key, false)
        return value if value.equal?(true) || value.equal?(false)

        raise ConfigurationError.new("#{key} must be true or false", code: "invalid_flag", source: source)
      end

      def valid_name(name, source, type)
        unless name.is_a?(Symbol) && !name.to_s.empty?
          raise ConfigurationError.new("#{type} name must be a non-empty symbol", code: "invalid_name", source: source)
        end

        name
      end

      def duplicate!(collection, name, code, source)
        return unless collection.key?(name)

        raise ConfigurationError.new("duplicate declaration for #{name.inspect}", code: code, source: source)
      end

      def overlap!(name, source)
        return unless inputs.key?(name) || exclusions.key?(name)

        raise ConfigurationError.new("input #{name.inspect} cannot be both analyzed and excluded",
                                     code: "input_exclusion_overlap", source: source)
      end

      def unknown_option!(option, source)
        raise ConfigurationError.new("unknown declaration option #{option.inspect}", code: "unknown_option",
                                                                                     source: source)
      end
    end

    # Collects partitions for one input declaration.
    class PartitionBuilder
      attr_reader :partitions

      def initialize(parent_domain, parent_form)
        @parent_domain = parent_domain
        @parent_form = parent_form
        @partitions = []
        @names = {}
      end

      def partition(name, **options)
        source = Loader.call_source
        unless name.is_a?(Symbol) && !name.to_s.empty?
          raise ConfigurationError.new("partition name must be a non-empty symbol", code: "invalid_name",
                                                                                    source: source)
        end
        if @names.key?(name)
          raise ConfigurationError.new("duplicate partition #{name.inspect}", code: "duplicate_partition",
                                                                              source: source)
        end

        domain_keys = options.keys & %i[range values]
        unless domain_keys.length == 1 && options.keys.length == 1
          raise ConfigurationError.new("partition must declare exactly one of range: or values:",
                                       code: "invalid_partition_domain", source: source)
        end

        form = domain_keys.first == :range ? :range : :values
        unless form == @parent_form
          raise ConfigurationError.new("partition domain form must match its input", code: "partition_domain_kind",
                                                                                     source: source)
        end

        domain = if form == :range
                   Domains.from_range(options[:range],
                                      source: source)
                 else
                   Domains.from_values(options[:values],
                                       source: source)
                 end
        @names[name] = true
        partitions << Partition.new(name: name, domain: domain, source: source)
      end
    end

    class << self
      def load(paths, allow_exclusion_only: false)
        paths = Array(paths)
        raise ConfigurationError.new("provide at least one specification file", code: "paths_required") if paths.empty?
        raise ConfigurationError.new("nested specification loading is not supported", code: "nested_load") if @active

        declarations = {}
        owns_context = false
        @active = declarations
        @allow_exclusion_only = allow_exclusion_only
        owns_context = true
        paths.map { |path| File.expand_path(File.path(path)) }.sort.each do |path|
          unless File.file?(path)
            raise ConfigurationError.new("specification file does not exist: #{path}", code: "file_not_found",
                                                                                       path: path)
          end

          @current_path = path
          TOPLEVEL_BINDING.eval(File.read(path), path, 1)
        end
        if declarations.empty?
          raise ConfigurationError.new("no specifications were declared", code: "empty_specifications")
        end

        unless allow_exclusion_only
          declarations.each_value do |specification|
            CombinationSpace.new(specification) if specification.combination_group
          end
        end

        declarations.values.freeze
      rescue Errno::ENOENT, Errno::EACCES => e
        raise ConfigurationError.new(e.message, code: "file_error",
                                                path: e.respond_to?(:path) ? e.path : nil)
      ensure
        if owns_context
          @active = nil
          @allow_exclusion_only = nil
          @current_path = nil
        end
      end

      def define(target, &block)
        source = call_source
        unless @active
          raise ConfigurationError.new("SpecProof.define may only be called while loading a specification",
                                       code: "outside_load", source: source)
        end
        unless valid_target?(target)
          raise ConfigurationError.new("target must use ClassName#instance_method syntax", code: "invalid_target",
                                                                                           source: source)
        end
        if @active.key?(target)
          raise ConfigurationError.new("duplicate target #{target}", code: "duplicate_target", source: source)
        end
        unless block
          raise ConfigurationError.new("target declaration requires a block", code: "missing_block", source: source)
        end

        builder = Builder.new(target, source)
        builder.instance_eval(&block)
        allowed_empty = @allow_exclusion_only && (!builder.exclusions.empty? || builder.combination_group)
        if builder.inputs.empty? && !allowed_empty
          raise ConfigurationError.new("target must declare at least one input", code: "inputs_required",
                                                                                 source: source)
        end

        @active[target] = Specification.new(target: target, inputs: builder.inputs, exclusions: builder.exclusions,
                                            combination_group: builder.combination_group, source: source)
      end

      def call_source
        location = caller_locations.find do |entry|
          !entry.path.end_with?("/specproof/loader.rb") && !entry.path.end_with?("/specproof/combinations.rb")
        end
        path = location&.absolute_path || location&.path || @current_path || "(unknown)"
        Source.new(path: path, line: location&.lineno || 1)
      end

      def valid_target?(target)
        target.is_a?(String) && target.match?(/\A[A-Z]\w*(?:::[A-Z]\w*)*#[a-z_]\w*[!?=]?\z/)
      end
    end
  end

  def self.define(target, &)
    Loader.define(target, &)
  end
end
