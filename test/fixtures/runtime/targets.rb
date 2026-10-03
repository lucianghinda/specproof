# frozen_string_literal: true

module RuntimeFixtures
  class Target
    class << self
      attr_accessor :optional_default_calls
    end

    def calculate(value, label:)
      [value, label]
    end

    alias calculate_alias calculate

    def recursive(value, depth:)
      return value if depth.zero?

      recursive(value, depth: depth - 1)
    end

    def failing(value)
      raise ArgumentError, value.to_s
    end

    def optional(value = 1)
      value
    end

    def mixed_optional(value = :position, label: :keyword)
      [value, label]
    end

    # Required positional arguments may follow optional ones in Ruby.
    # rubocop:disable-next Style/OptionalArguments
    def optional_before_required(optional = :optional, required)
      [optional, required]
    end

    def dependent_default(first = 2, second = first + 1)
      [first, second]
    end

    def side_effect_default(value = next_default_value)
      value
    end

    def next_default_value
      self.class.optional_default_calls = self.class.optional_default_calls.to_i + 1
      :default_value
    end

    def raising_default(value = raise_default_error)
      value
    end

    def raise_default_error
      raise ArgumentError, "default failed"
    end

    def opaque_default(value = Object.new, label: :ok)
      [value, label]
    end

    def helper(value)
      value
    end

    def calls_helper_by_default(value = helper(:from_default))
      value
    end

    def with_rest(value, *others)
      [value, others]
    end

    def with_keyrest(value, **options)
      [value, options]
    end

    def with_block(value, &callback)
      callback ? callback.call(value) : value
    end

    def with_forwarding(...)
      helper(...)
    end
  end

  class Child < Target
    def calculate(value, label:)
      [:child, value, label]
    end
  end

  class SuperChild < Target
    def calculate(value, label:)
      [:child, super]
    end
  end

  class Replaced
    def run(value)
      value
    end
  end

  class Dynamic
    define_method(:run) { |value| value }
  end

  class StringMutation
    def mutate(value)
      value.replace("changed")
    end
  end
end

RuntimeFixturesAlias = RuntimeFixtures::Target

module RuntimeBindingFixtures
  class Original
    def run(value)
      value
    end
  end

  module Namespace
    class NestedOriginal
      def run(value)
        value
      end
    end
  end
end

module RuntimeAutoloadFixtures
  autoload :LoadedOnAccess, File.expand_path("autoloaded.rb", __dir__)
end
