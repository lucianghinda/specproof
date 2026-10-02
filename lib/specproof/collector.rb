# frozen_string_literal: true

module SpecProof
  # Captures method calls during a test run and matches them to obligations.
  class Collector
    # `method` is part of the collector's internal target record.
    # rubocop:disable-next Lint/StructNewOverride
    Target = Struct.new(:name, :owner, :constant_names, :method_name, :method, :method_ids, :input_names,
                        keyword_init: true)

    def initialize(specifications:, observer:)
      @specifications = specifications
      @observer = observer
      @issues = []
      @issue_keys = {}
      @disabled_targets = {}
      @tracepoint = nil
      @pid = nil
      @thread = nil
    end

    def start
      raise_configuration_error("collector is already started", code: "collector_already_started") if enabled?

      targets = @specifications.map { |specification| build_target(specification) }
      duplicate = targets.group_by(&:name).find { |_name, entries| entries.length > 1 }
      if duplicate
        raise_configuration_error("duplicate target #{duplicate.first}", target: duplicate.first,
                                                                         code: "duplicate_target")
      end

      duplicate_binding = {}
      targets.each do |target|
        target.method_ids.each do |method_id|
          binding = [target.owner, method_id]
          if duplicate_binding.key?(binding)
            raise_configuration_error("multiple targets resolve to the same runtime method binding",
                                      target: target.name, code: "duplicate_binding")
          end

          duplicate_binding[binding] = target
        end
      end

      @targets = targets.to_h { |target| [target.name, target] }
      @target_methods = duplicate_binding
      @disabled_targets = {}
      @pid = Process.pid
      @thread = Thread.current
      @tracepoint = TracePoint.new(:call) { |trace| collect(trace) }
      @tracepoint.enable
      self
    rescue StandardError => e
      @tracepoint&.disable
      @tracepoint = nil
      @targets = nil
      @target_methods = nil
      raise if configuration_error?(e)

      raise_configuration_error("collector could not start: #{e.class}", code: "collector_start_failed")
    end

    def stop
      tracepoint = @tracepoint
      return nil unless tracepoint

      begin
        tracepoint.disable
      ensure
        @tracepoint = nil
        @targets&.each_value do |target|
          report_redefinition(target)
          report_binding_change(target)
        end
        @target_methods = nil
        @pid = nil
        @thread = nil
      end
      nil
    end

    def enabled?
      @tracepoint&.enabled? || false
    end

    def issues
      @issues.map { |issue| issue.dup.freeze }.freeze
    end

    private

    def build_target(specification)
      target_name = specification.target
      unless target_name.is_a?(String) && !target_name.empty?
        raise_configuration_error("target must be a non-empty String", code: "invalid_target")
      end

      owner_name, method_name = parse_target(target_name)
      owner = resolve_class(owner_name, target_name)
      unless owner.is_a?(Class)
        raise_configuration_error("target owner must be a Class", target: target_name, code: "invalid_target_owner")
      end

      method_symbol = method_name.to_sym
      unless owner.public_method_defined?(method_symbol, false)
        raise_configuration_error("#{target_name} must name a directly defined public instance method",
                                  target: target_name, code: "invalid_method")
      end

      method = owner.instance_method(method_symbol)
      unless method.owner == owner && method.original_name == method_symbol
        raise_configuration_error("#{target_name} cannot name an inherited or aliased method", target: target_name,
                                                                                               code: "invalid_method")
      end

      if method.source_location.nil?
        raise_configuration_error("#{target_name} must have a Ruby source location", target: target_name,
                                                                                     code: "invalid_method")
      end

      input_names = specification.inputs.keys
      unless input_names.all?(Symbol)
        raise_configuration_error("#{target_name} inputs must use symbol names", target: target_name,
                                                                                 code: "invalid_inputs")
      end

      parameters = method.parameters
      unless parameters.all? { |kind, _name| %i[req opt keyreq key].include?(kind) }
        raise_configuration_error("#{target_name} may only use named positional or keyword parameters",
                                  target: target_name, code: "unsupported_parameters")
      end

      declared_names = parameters.map(&:last)
      input_names_match = specification.inputs.all? do |name, input|
        input.name == name
      end
      names_match = declared_names.none?(&:nil?) && declared_names.sort == input_names.sort
      unless names_match && input_names_match
        raise_configuration_error("#{target_name} parameters must exactly match declared input names",
                                  target: target_name, code: "parameter_mismatch")
      end

      method_ids = owner.public_instance_methods(false).select do |candidate|
        owner.instance_method(candidate) == method
      rescue NameError
        false
      end

      Target.new(
        name: target_name.freeze,
        owner: owner,
        constant_names: owner_name.map(&:freeze).freeze,
        method_name: method_symbol,
        method: method,
        method_ids: method_ids.freeze,
        input_names: declared_names.freeze
      ).freeze
    end

    def parse_target(target_name)
      match = /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)#([a-zA-Z_]\w*[!?=]?)\z/.match(target_name)
      unless match
        raise_configuration_error("target must use Class::Name#method syntax", target: target_name,
                                                                               code: "invalid_target")
      end

      [match[1].split("::"), match[2]]
    end

    def resolve_class(constant_names, target_name)
      value = Object
      constant_names.each do |constant_name|
        symbol = constant_name.to_sym
        if value.autoload?(symbol)
          raise_configuration_error("#{target_name} cannot resolve an autoloaded constant", target: target_name,
                                                                                            code: "autoloaded_target")
        end
        unless value.const_defined?(symbol, false)
          raise_configuration_error("#{target_name} references an undefined constant", target: target_name,
                                                                                       code: "undefined_target")
        end

        value = value.const_get(symbol, false)
      end
      value
    end

    def collect(trace)
      return unless Process.pid == @pid && Thread.current.equal?(@thread)

      target = @target_methods[[trace.defined_class, trace.method_id]]
      return unless target
      return if target.owner != trace.defined_class
      return if @disabled_targets[target.name]

      unless method_unchanged?(target)
        disable_target(target, "target_redefined")
        return
      end

      arguments = copy_arguments(trace, target)
      @observer.observe(target: target.name, arguments: arguments)
    rescue StandardError => e
      disable_target(target, error_code(e)) if target
    end

    def copy_arguments(trace, target)
      binding = trace.binding
      target.input_names.to_h do |name|
        value = binding.local_variable_get(name)
        raise ArgumentError, "non_primitive_argument" unless primitive?(value)

        [name, value]
      end.freeze
    end

    def primitive?(value)
      case value
      when NilClass, TrueClass, FalseClass, Integer, Symbol then true
      else false
      end
    end

    def error_code(error)
      return "non_primitive_argument" if error.message == "non_primitive_argument"
      return "binding_failure" if error.is_a?(NameError)

      "observer_error"
    end

    def disable_target(target, code)
      @disabled_targets[target.name] = true
      add_issue(target.name, code, "collector disabled this target after an observation failure")
    end

    def report_redefinition(target)
      return if method_unchanged?(target)

      add_issue(target.name, "target_redefined", "target method changed while collection was active")
    end

    def report_binding_change(target)
      return if target_binding_unchanged?(target)

      add_issue(target.name, "target_binding_changed", "target constant binding changed while collection was active")
    end

    def target_binding_unchanged?(target)
      value = Object
      target.constant_names.each do |constant_name|
        return false unless value.is_a?(Module)

        symbol = constant_name.to_sym
        return false if value.autoload?(symbol) || !value.const_defined?(symbol, false)

        value = value.const_get(symbol, false)
      end
      value.equal?(target.owner)
    rescue NameError
      false
    end

    def method_unchanged?(target)
      target.owner.instance_method(target.method_name) == target.method
    rescue NameError
      false
    end

    def add_issue(target, code, message)
      key = [target, code]
      return if @issue_keys[key]

      @issue_keys[key] = true
      @issues << { target: target, code: code, message: message }.freeze
    end

    def raise_configuration_error(message, target: nil, code: "configuration_error")
      add_issue(target, code, message)
      error_class = SpecProof.const_get(:ConfigurationError, false)
      raise error_class.new(message, code: code)
    end

    def configuration_error?(error)
      error.is_a?(SpecProof.const_get(:ConfigurationError, false))
    rescue NameError
      false
    end
  end
end
