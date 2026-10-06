# frozen_string_literal: true

module SpecProof
  # Converts supported Ruby method references into stable target strings.
  module TargetName
    OWNER_PATTERN = /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/
    METHOD_PATTERN = /\A[a-z_]\w*[!?=]?\z/
    TARGET_PATTERN = /\A([A-Z]\w*(?:::[A-Z]\w*)*)(#|\.)([a-z_]\w*[!?=]?)\z/

    module_function

    def normalize(target, source: nil)
      if target.is_a?(String)
        begin
          parse(target)
        rescue ConfigurationError => e
          raise ConfigurationError.new(e.message, code: e.code, source: source)
        end
        return target
      end
      return normalize_method(target, source) if target.is_a?(Method) || target.is_a?(UnboundMethod)

      invalid_target!("target must be a String, Method, or UnboundMethod", source)
    end

    def parse(string)
      match = TARGET_PATTERN.match(string)
      unless match
        raise ConfigurationError.new("target must use Owner#method or Owner.method syntax", code: "invalid_target")
      end

      [match[1], match[3].to_sym, match[2] == "#" ? :instance : :singleton]
    end

    def normalize_method(method, source)
      kind = method.is_a?(Method) ? :singleton : :instance
      owner = method_owner(method, kind, source)
      unless owner.is_a?(Class) || (kind == :singleton && owner.is_a?(Module))
        invalid_target!("instance methods must be defined on a named class", source)
      end

      owner_path = owner.name
      validate_named_owner!(owner, owner_path, source)
      validate_definition!(owner, method, kind, source)
      "#{owner_path}#{kind == :instance ? "#" : "."}#{method.name}"
    rescue NameError
      invalid_target!("method owner must be bound to its named constant", source)
    end

    def method_owner(method, kind, source)
      return method.owner unless kind == :singleton

      receiver = method.receiver
      unless receiver.is_a?(Module) && method.owner.equal?(receiver.singleton_class)
        invalid_target!("bound methods must belong to a named class or module", source)
      end
      receiver
    end
    private_class_method :method_owner

    def validate_named_owner!(owner, owner_path, source)
      return if owner_path && OWNER_PATTERN.match?(owner_path) && resolve_owner(owner_path).equal?(owner)

      invalid_target!("method owner must be bound to its named constant", source)
    end
    private_class_method :validate_named_owner!

    def validate_definition!(owner, method, kind, source)
      name = method.name
      unless METHOD_PATTERN.match?(name.to_s) && method.original_name == name
        invalid_target!("target method must be a directly defined method, not an alias", source)
      end
      invalid_target!("target method must be implemented in Ruby source", source) unless method.source_location

      public_methods = kind == :singleton ? owner.public_methods(false) : owner.public_instance_methods(false)
      invalid_target!("target method must be public and directly defined", source) unless public_methods.include?(name)

      current = kind == :singleton ? owner.method(name) : owner.instance_method(name)
      return if current == method

      invalid_target!("target method object is stale or no longer directly defined", source)
    end
    private_class_method :validate_definition!

    def resolve_owner(path)
      path.split("::").reduce(Object) do |namespace, name|
        return nil unless namespace.is_a?(Module)
        return nil unless namespace.const_defined?(name, false) && !namespace.autoload?(name)

        namespace.const_get(name, false)
      end
    end
    private_class_method :resolve_owner

    def invalid_target!(message, source)
      raise ConfigurationError.new(message, code: "invalid_target", source: source)
    end
    private_class_method :invalid_target!
  end
end
