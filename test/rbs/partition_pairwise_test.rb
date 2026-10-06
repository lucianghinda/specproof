# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"

class RBSPartitionPairwiseTest < Minitest::Test
  PARTITION_CRITERION = "pairwise-partitions-v1"

  def test_integer_refinements_cross_with_rbs_string_choices
    Dir.mktmpdir("specproof-rbs-partitions") do |directory|
      dsl_path = File.join(directory, "registration.rb")
      rbs_path = File.join(directory, "registration.rbs")
      File.write(dsl_path, <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120, exhaustive: true, disjoint: true do
            partition :minor, range: 0...18
            partition :adult, range: 18..120
          end
          combinations :age, :country, all_allowed: true
        end
      RUBY
      File.write(rbs_path, <<~RBS)
        class Registration
          def eligible?: (age: Integer, country: "ro" | "de") -> bool
        end
      RBS

      specs = SpecProof.load([dsl_path], rbs: [rbs_path], targets: ["Registration#eligible?"])
      assert_empty SpecProof.check(specs)
      obligations = SpecProof.plan(specs, criterion: "pairwise-partitions-v1")
      assert_equal 4, obligations.length
      assert_equal %w[de ro], specs.first.inputs.fetch(:country).domain.values
      assert(obligations.all? { |item| item.sources.any? { |source| source.kind == "rbs" } })

      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specs)
      [[16, "ro"], [30, "ro"], [30, "de"]].each do |age, country|
        coverage.observe(target: "Registration#eligible?", arguments: { age: age, country: country })
      end
      report = coverage.to_report
      assert_equal 3, report.fetch(:exercised_count)
      assert_equal 1, report.fetch(:not_observed_count)
      missing = report.fetch(:missing).first
      assert_equal "minor", missing.fetch(:inputs).fetch("age").fetch(:name)
      assert_equal "de", missing.fetch(:inputs).fetch("country").fetch(:value)
    end
  end

  def test_partition_restriction_refines_rbs_finite_domains
    Dir.mktmpdir("specproof-rbs-constrained-partitions") do |directory|
      dsl_path = File.join(directory, "registration.rb")
      rbs_path = File.join(directory, "registration.rbs")
      File.write(dsl_path, <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120, exhaustive: true, disjoint: true do
            partition :minor, range: 0...18
            partition :adult, range: 18..120
          end
          combinations :age, :account, :country do
            forbid age: in_partition(:minor), account: "business"
          end
        end
      RUBY
      File.write(rbs_path, <<~RBS)
        class Registration
          def eligible?: (age: Integer, account: "personal" | "business", country: "ro" | "de") -> bool
        end
      RBS

      specs = SpecProof.load([dsl_path], rbs: [rbs_path], targets: ["Registration#eligible?"])
      assert_empty SpecProof.check(specs)
      obligations = SpecProof.plan(specs, criterion: PARTITION_CRITERION)
      assert_equal 11, obligations.length
      space = SpecProof::PartitionSpace.new(specs.first)
      assert_equal 1, space.excluded_pairs.length
      assert_equal %w[business personal], specs.first.inputs.fetch(:account).domain.values
      assert(obligations.all? { |item| item.sources.any? { |source| source.kind == "rbs" } })

      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specs)
      refute coverage.observe(target: "Registration#eligible?",
                              arguments: { age: 16, account: "business", country: "ro" })
      assert coverage.observe(target: "Registration#eligible?",
                              arguments: { age: 16, account: "personal", country: "ro" })
      report = coverage.to_report
      assert_equal 3, report.fetch(:exercised_count)
      assert_equal 1, report.fetch(:outside_combinations).fetch("Registration#eligible?").fetch(:count)
    end
  end
end
