# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

class RBSPairwiseTest < Minitest::Test
  def test_combinations_only_dsl_composes_with_rbs_finite_inputs
    Dir.mktmpdir("specproof-rbs-pairwise", "/private/tmp") do |directory|
      dsl_path = File.join(directory, "pairwise.rb")
      rbs_path = File.join(directory, "delivery.rbs")
      File.write(dsl_path, <<~RUBY)
        SpecProof.define "Delivery#build" do
          combinations :expedited, :notify, all_allowed: true
        end
      RUBY
      File.write(rbs_path, <<~RBS)
        class Delivery
          def build: (expedited: bool, notify: bool) -> void
        end
      RBS

      specification = SpecProof.load([dsl_path], rbs: [rbs_path], targets: ["Delivery#build"]).fetch(0)

      assert_equal %i[expedited notify], specification.combination_group.inputs
      assert_equal 4, SpecProof.plan([specification], criterion: "pairwise-finite-v1").length
      assert_equal "rbs", specification.inputs.fetch(:expedited).type_sources.fetch(0).kind
    end
  end
end
