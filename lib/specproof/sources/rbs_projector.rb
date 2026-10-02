# frozen_string_literal: true

module SpecProof
  module Sources
    # Projects selected RBS methods into SpecProof's deliberately small scalar model.
    class RBSProjector
      def initialize(target, environment, paths, rbs)
        @target = target
        @environment = environment
        @paths = paths
        @rbs = rbs
      end

      def facts
        owner = @target.split("#", 2).first
        declarations = owner_declarations(owner, @environment, @paths)
        method, visibility = select_method(@target, declarations, @rbs)
        validate_method!(@target, method, visibility, generic_owner?(owner, @environment))
        input_facts(@target, method, @rbs)
      end

      private

      attr_reader :rbs

      def owner_declarations(owner, environment, paths)
        entries = environment.class_decls.select { |name, _entry| normalize_type_name(name) == owner }
        entries.flat_map do |_name, entry|
          owner_declarations = entry.each_decl.select do |declaration|
            declaration.is_a?(rbs::AST::Declarations::Class) || declaration.is_a?(rbs::AST::Declarations::Module)
          end
          owner_declarations.select do |declaration|
            supplied_declaration?(declaration, paths)
          end
        end
      end

      def generic_owner?(owner, environment)
        environment.class_decls.any? do |name, entry|
          normalize_type_name(name) == owner && entry.each_decl.any? do |declaration|
            (declaration.is_a?(rbs::AST::Declarations::Class) ||
              declaration.is_a?(rbs::AST::Declarations::Module)) && !declaration.type_params.empty?
          end
        end
      end

      def select_method(target, declarations, rbs)
        method_name = target.split("#", 2).last
        matches = matching_members(method_name, declarations, rbs)
        module_method = matching_module_method(method_name, declarations, rbs)
        unsupported_signature!(target, module_method, "module owners are not supported") if module_method

        if matches[:attribute]
          unsupported_signature!(target, matches[:attribute], "generated attribute methods are not supported")
        end
        if matches[:instance_alias]
          unsupported_signature!(target, matches[:instance_alias], "method aliases are not supported")
        end
        methods = matches[:instance]
        if methods.empty?
          if matches[:instance_alias] || matches[:singleton_alias]
            unsupported_signature!(target, matches[:instance_alias] || matches[:singleton_alias],
                                   "method aliases are not supported")
          end
          if matches[:singleton]
            unsupported_signature!(target, matches[:singleton], "singleton methods are not supported")
          end
          raise ConfigurationError.new("RBS target was not found: #{target}", code: "rbs_target_not_found")
        end
        if methods.length > 1
          unsupported_signature!(target, methods.first.first,
                                 "method is declared more than once across class reopenings")
        end

        methods.first
      end

      def matching_members(method_name, declarations, rbs)
        matches = { instance: [], singleton: nil, instance_alias: nil, singleton_alias: nil, attribute: nil }
        declarations.each do |declaration|
          visibility = :public
          declaration.members.each do |member|
            case member
            when rbs::AST::Members::Public then visibility = :public
            when rbs::AST::Members::Private then visibility = :private
            when rbs::AST::Members::MethodDefinition
              add_matching_method(matches, member, visibility, method_name)
            when rbs::AST::Members::Alias
              if member.new_name.to_s == method_name
                key = member.instance? ? :instance_alias : :singleton_alias
                matches[key] = member
              end
            when rbs::AST::Members::Attribute
              matches[:attribute] = member if generated_attribute?(member, method_name, rbs)
            end
          end
        end
        matches
      end

      def add_matching_method(matches, member, visibility, method_name)
        return unless member.name.to_s == method_name

        member.instance? ? matches[:instance] << [member, visibility] : matches[:singleton] = member
      end

      def generated_attribute?(member, method_name, rbs)
        reader = member.name.to_s == method_name && !member.is_a?(rbs::AST::Members::AttrWriter)
        writer = method_name == "#{member.name}=" && !member.is_a?(rbs::AST::Members::AttrReader)
        member.kind == :instance && (reader || writer)
      end

      def matching_module_method(method_name, declarations, rbs)
        declarations.grep(rbs::AST::Declarations::Module).lazy.flat_map(&:members).find do |member|
          member.respond_to?(:name) && member.name.to_s == method_name
        end
      end

      def validate_method!(target, method, visibility, generic_owner)
        if (method.visibility || visibility) != :public
          unsupported_signature!(target, method, "only directly declared public instance methods are supported")
        end
        unsupported_signature!(target, method, "singleton methods are not supported") if method.singleton?
        if method.overloading? || method.overloads.length != 1
          unsupported_signature!(target, method, "overloaded method signatures are not supported")
        end
        if method.overloads.any? { |overload| !overload.annotations.empty? }
          unsupported_signature!(target, method, "method type extension annotations are not supported")
        end
        unsupported_signature!(target, method, "generic owner classes are not supported") if generic_owner

        method_type = method.overloads.fetch(0).method_type
        unsupported_signature!(target, method, "generic methods are not supported") if method_type.type_params.any?
        function = method_type.type
        return unless method_type.block || function.forwarding? || function.rest_positionals || function.rest_keywords

        unsupported_signature!(target, method, "blocks, rest arguments, and forwarding are not supported")
      end

      def input_facts(target, method, rbs)
        function = method.overloads.fetch(0).method_type.type
        params = function.required_positionals + function.optional_positionals + function.trailing_positionals
        params.each do |param|
          unless param.name && !param.name.to_s.empty?
            unsupported_signature!(target, method, "every positional parameter must have an explicit name")
          end
        end
        keyword_params = function.required_keywords.merge(function.optional_keywords)
        duplicate_keywords = function.required_keywords.keys & function.optional_keywords.keys
        unless duplicate_keywords.empty?
          unsupported_signature!(target, method, "keyword parameter names must be unique")
        end
        names = params.map { |param| param.name.to_sym } + keyword_params.keys.map(&:to_sym)
        unsupported_signature!(target, method, "target method must have at least one input") if names.empty?
        unsupported_signature!(target, method, "parameter names must be unique") if names.uniq.length != names.length

        named_params = params.map { |param| [param.name.to_sym, param] } +
                       keyword_params.map { |name, param| [name.to_sym, param] }
        named_params.map do |name, param|
          constraint = map_type(param.type, target, name, rbs)
          InputTypeFact.new(target: target, input: name, constraint: constraint,
                            source: source_for(param))
        end
      end

      def map_type(type, target, input, rbs)
        case type
        when rbs::Types::Union
          TypeConstraints.union(type.types.map { |alternative| map_type(alternative, target, input, rbs) })
        when rbs::Types::Optional
          TypeConstraints.union([
                                  map_type(type.type, target, input, rbs),
                                  ScalarTypeConstraint.new(integer_any: false, values: [nil])
                                ])
        when rbs::Types::Bases::Bool
          ScalarTypeConstraint.new(integer_any: false, values: [true, false])
        when rbs::Types::Bases::Nil
          ScalarTypeConstraint.new(integer_any: false, values: [nil])
        when rbs::Types::Literal
          value = type.literal
          supported = value.nil? || value.equal?(true) || value.equal?(false) ||
                      value.is_a?(Integer) || value.is_a?(Symbol)
          unsupported_type!(target, input, type) unless supported
          ScalarTypeConstraint.new(integer_any: false, values: [value])
        when rbs::Types::ClassInstance
          if builtin_integer?(type) && type.args.empty?
            ScalarTypeConstraint.new(integer_any: true, values: [])
          else
            unsupported_type!(target, input, type)
          end
        else
          unsupported_type!(target, input, type)
        end
      end

      def builtin_integer?(type)
        name = type.name
        name.name == :Integer && name.namespace.absolute? && name.namespace.path.empty?
      end

      def unsupported_type!(target, input, type)
        raise ConfigurationError.new("unsupported RBS input type #{type}: #{target} / input #{input}",
                                     code: "unsupported_rbs_type", source: source_for(type))
      end

      def unsupported_signature!(target, method, reason)
        raise ConfigurationError.new("#{reason}: #{target}", code: "unsupported_rbs_signature",
                                                             source: source_for(method))
      end

      def source_for(node)
        location = node.respond_to?(:location) ? node.location : node
        Source.new(path: location.buffer.name.to_s, line: location.start_line, kind: "rbs")
      end

      def supplied_declaration?(declaration, paths)
        paths.include?(File.expand_path(declaration.location.buffer.name.to_s))
      end

      def normalize_type_name(name)
        name.to_s.sub(/\A::/, "")
      end
    end
    private_constant :RBSProjector
  end
end
