# frozen_string_literal: true

module RuntimeAutoloadFixtures
  class LoadedOnAccess
    def run(value)
      value
    end
  end
end
