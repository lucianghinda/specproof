# frozen_string_literal: true

module RuntimeFixtures
  class Target
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
