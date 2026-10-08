# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "specproof/collector"

module SingletonCollectorFixtures
  class Target
    def build(value = 1, label: :default)
      [value, label]
    end

    def self.build(value = 1, label: :default)
      [value, label]
    end

    def self.with_excluded(value = 1, ignored: :ignored)
      [value, ignored]
    end

    class << self
      alias build_alias build

      private

      def hidden(value)
        value
      end
    end
  end

  class Child < Target; end

  module Namespace
    def self.build(value)
      value
    end
  end

  class Replaced
    def self.run(value)
      value
    end
  end
end

class SingletonCollectorTest < Minitest::Test
  Input = Struct.new(:name, :domain, keyword_init: true)
  Exclusion = Struct.new(:name, :reason, :source, keyword_init: true)
  Specification = Struct.new(:target, :inputs, :exclusions, keyword_init: true)

  class Observer
    attr_reader :calls

    def initialize
      @calls = []
    end

    def observe(target:, arguments:)
      calls << [target, arguments]
    end
  end

  def setup
    @observer = Observer.new
  end

  def test_collects_public_singleton_methods_on_classes_and_modules
    class_collector = collector_for("SingletonCollectorFixtures::Target.build", :value, :label)
    module_collector = collector_for("SingletonCollectorFixtures::Namespace.build", :value)
    class_collector.start
    module_collector.start

    SingletonCollectorFixtures::Target.build(7, label: :class_call)
    SingletonCollectorFixtures::Namespace.build(9)

    class_collector.stop
    module_collector.stop

    assert_equal [
      ["SingletonCollectorFixtures::Target.build", { value: 7, label: :class_call }],
      ["SingletonCollectorFixtures::Namespace.build", { value: 9 }]
    ], @observer.calls
    assert_empty class_collector.issues
    assert_empty module_collector.issues
  end

  def test_instance_and_singleton_methods_with_the_same_name_are_independent
    collector = SpecProof::Collector.new(
      specifications: [
        spec("SingletonCollectorFixtures::Target#build", :value, :label),
        spec("SingletonCollectorFixtures::Target.build", :value, :label)
      ],
      observer: @observer
    )
    collector.start

    SingletonCollectorFixtures::Target.new.build(2, label: :instance)
    SingletonCollectorFixtures::Target.build(3, label: :singleton)
    collector.stop

    assert_equal [
      ["SingletonCollectorFixtures::Target#build", { value: 2, label: :instance }],
      ["SingletonCollectorFixtures::Target.build", { value: 3, label: :singleton }]
    ], @observer.calls
    assert_empty collector.issues
  end

  def test_observes_calls_through_aliases_of_the_selected_singleton_definition
    collector = collector_for("SingletonCollectorFixtures::Target.build", :value, :label)
    collector.start
    SingletonCollectorFixtures::Target.build_alias(4, label: :alias_call)
    collector.stop

    assert_equal [["SingletonCollectorFixtures::Target.build", { value: 4, label: :alias_call }]], @observer.calls
    assert_empty collector.issues
  end

  def test_inherited_singleton_calls_retain_definition_level_collection_semantics
    collector = collector_for("SingletonCollectorFixtures::Target.build", :value, :label)
    collector.start
    SingletonCollectorFixtures::Child.build(5, label: :inherited_call)
    collector.stop

    assert_equal [["SingletonCollectorFixtures::Target.build", { value: 5, label: :inherited_call }]], @observer.calls
    assert_empty collector.issues
  end

  def test_optional_defaults_and_excluded_inputs_are_collected
    exclusions = { ignored: Exclusion.new(name: :ignored, reason: "not modeled") }
    collector = SpecProof::Collector.new(
      specifications: [spec("SingletonCollectorFixtures::Target.with_excluded", :value, exclusions: exclusions)],
      observer: @observer
    )
    collector.start
    SingletonCollectorFixtures::Target.with_excluded
    collector.stop

    assert_equal [["SingletonCollectorFixtures::Target.with_excluded", { value: 1 }]], @observer.calls
    assert_empty collector.issues
  end

  def test_rejects_inherited_aliased_private_and_native_singleton_declarations
    [
      ["SingletonCollectorFixtures::Child.build", :invalid_method],
      ["SingletonCollectorFixtures::Target.build_alias", :invalid_method],
      ["SingletonCollectorFixtures::Target.hidden", :invalid_method],
      ["Math.sqrt", :invalid_method]
    ].each do |target, code|
      collector = collector_for(target, :value)

      error = assert_raises(SpecProof::ConfigurationError) { collector.start }

      assert_equal code.to_s, error.code
      refute collector.enabled?
    end
  end

  def test_redefinition_during_collection_is_reported_and_not_observed
    collector = collector_for("SingletonCollectorFixtures::Replaced.run", :value)
    collector.start
    SingletonCollectorFixtures::Replaced.define_singleton_method(:run) { |value| [:new, value] }

    assert_equal [:new, 6], SingletonCollectorFixtures::Replaced.run(6)
    collector.stop

    assert_empty @observer.calls
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_redefined"], issue_codes
  end

  def test_constant_rebinding_is_reported_for_singleton_targets
    original = SingletonCollectorFixtures::Target
    collector = collector_for("SingletonCollectorFixtures::Target.build", :value, :label)
    collector.start
    original.build(8, label: :before_rebind)
    SingletonCollectorFixtures.send(:remove_const, :Target)
    SingletonCollectorFixtures.const_set(:Target, Class.new do
      def self.build(value = 1, label: :default)
        [value, label]
      end
    end)
    collector.stop

    assert_equal [["SingletonCollectorFixtures::Target.build", { value: 8, label: :before_rebind }]], @observer.calls
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_binding_changed"], issue_codes
  ensure
    if original
      if SingletonCollectorFixtures.const_defined?(:Target, false)
        SingletonCollectorFixtures.send(:remove_const, :Target)
      end
      SingletonCollectorFixtures.const_set(:Target, original)
    end
  end

  def test_minitest_subprocess_reports_singleton_obligation_hits
    Dir.mktmpdir("specproof-singleton-minitest") do |directory|
      specification_path = File.join(directory, "singleton_spec.rb")
      report_path = File.join(directory, "coverage.json")
      File.write(specification_path, <<~SPEC)
        SpecProof.define "SingletonPolicy.build" do
          input :value, values: [1, 2]
        end
      SPEC
      script = <<~RUBY
        gem "minitest", "~> 5.26.2"
        $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
        require "specproof"
        require "minitest/autorun"

        class SingletonPolicy
          def self.build(value)
            value
          end
        end

        class SingletonCoverageTest < Minitest::Test
          def test_values
            assert_equal 1, SingletonPolicy.build(1)
            assert_equal 2, SingletonPolicy.build(2)
          end
        end

        require "specproof/minitest"
        SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], output: ENV.fetch("REPORT_PATH"))
      RUBY
      env = {
        "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
        "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil,
        "MT_NO_PLUGINS" => "1", "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
        "SPEC_PATH" => specification_path, "REPORT_PATH" => report_path
      }
      _stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
      assert_equal ["SingletonPolicy.build"], report.dig("scope", "targets")
      assert(report.fetch("obligations").all? do |row|
        row.fetch("status") == "exercised" && row.fetch("hits") == 1
      end)
    end
  end

  private

  def spec(target, *inputs, exclusions: {})
    Specification.new(target: target, inputs: inputs.to_h { |name| [name, Input.new(name: name)] }.freeze,
                      exclusions: exclusions)
  end

  def collector_for(target, *inputs, exclusions: {})
    SpecProof::Collector.new(specifications: [spec(target, *inputs, exclusions: exclusions)], observer: @observer)
  end
end
