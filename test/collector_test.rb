# frozen_string_literal: true

require_relative "test_helper"
require_relative "fixtures/runtime/targets"
require "specproof/collector"

class CollectorTest < Minitest::Test
  Input = Struct.new(:name, :domain, keyword_init: true)
  Specification = Struct.new(:target, :inputs, keyword_init: true)

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
    @collector = SpecProof::Collector.new(
      specifications: [spec("RuntimeFixtures::Target#calculate", :value, :label)],
      observer: @observer
    )
  end

  def test_observes_matching_calls_with_positional_and_keyword_values
    RuntimeFixtures::Target.new.calculate(6, label: :before)
    @collector.start
    assert_equal [7, :plain], RuntimeFixtures::Target.new.calculate(7, label: :plain)
    @collector.stop
    RuntimeFixtures::Target.new.calculate(9, label: :after)

    assert_equal [["RuntimeFixtures::Target#calculate", { value: 7, label: :plain }]], @observer.calls
    assert_empty @collector.issues
  end

  def test_observes_recursive_calls_as_distinct_invocations
    @collector = SpecProof::Collector.new(
      specifications: [spec("RuntimeFixtures::Target#recursive", :value, :depth)],
      observer: @observer
    )
    @collector.start
    assert_equal :leaf, RuntimeFixtures::Target.new.recursive(:leaf, depth: 2)
    @collector.stop

    assert_equal 3, @observer.calls.length
    assert_equal([2, 1, 0], @observer.calls.map { |_target, arguments| arguments[:depth] })
  end

  def test_alias_invocation_of_the_target_method_is_observed
    @collector.start
    RuntimeFixtures::Target.new.calculate_alias(7, label: :alias_call)
    @collector.stop

    assert_equal [["RuntimeFixtures::Target#calculate", { value: 7, label: :alias_call }]], @observer.calls
  end

  def test_ignores_subclass_override_without_super
    @collector.start
    RuntimeFixtures::Child.new.calculate(4, label: :child)
    @collector.stop

    assert_empty @observer.calls
  end

  def test_observes_super_called_by_a_subclass_override
    @collector.start
    RuntimeFixtures::SuperChild.new.calculate(4, label: :super_call)
    @collector.stop

    assert_equal [["RuntimeFixtures::Target#calculate", { value: 4, label: :super_call }]], @observer.calls
  end

  def test_ignores_calls_from_other_threads
    @collector.start
    Thread.new { RuntimeFixtures::Target.new.calculate(4, label: :worker) }.join
    RuntimeFixtures::Target.new.calculate(5, label: :main)
    @collector.stop

    assert_equal [["RuntimeFixtures::Target#calculate", { value: 5, label: :main }]], @observer.calls
  end

  def test_observer_failure_does_not_change_return_value_or_raise_into_application
    observer = Object.new
    def observer.observe(**)
      raise "observer failed"
    end
    @collector = SpecProof::Collector.new(
      specifications: [spec("RuntimeFixtures::Target#calculate", :value, :label)],
      observer: observer
    )
    @collector.start

    assert_equal [8, :safe], RuntimeFixtures::Target.new.calculate(8, label: :safe)
    @collector.stop

    assert_equal(["RuntimeFixtures::Target#calculate"], @collector.issues.map { |issue| issue[:target] })
    assert_equal(["observer_error"], @collector.issues.map { |issue| issue[:code] })
    assert_equal 1, @collector.issues.length
  end

  def test_preserves_application_exception
    @collector = SpecProof::Collector.new(
      specifications: [spec("RuntimeFixtures::Target#failing", :value)],
      observer: @observer
    )
    @collector.start

    error = assert_raises(ArgumentError) { RuntimeFixtures::Target.new.failing(11) }
    @collector.stop

    assert_equal "11", error.message
    assert_equal [["RuntimeFixtures::Target#failing", { value: 11 }]], @observer.calls
  end

  def test_start_rejects_undefined_targets_without_leaving_trace_active
    collector = collector_for("RuntimeFixtures::Target#missing", :value)

    assert_raises(SpecProof::ConfigurationError) { collector.start }
    refute collector.enabled?
    assert_equal [1, :x], RuntimeFixtures::Target.new.calculate(1, label: :x)
    assert_empty @observer.calls
  end

  def test_start_rejects_autoloaded_targets_without_triggering_autoload
    collector = collector_for("RuntimeAutoloadFixtures::LoadedOnAccess#run", :value)

    assert_raises(SpecProof::ConfigurationError) { collector.start }

    assert RuntimeAutoloadFixtures.autoload?(:LoadedOnAccess)
    refute collector.enabled?
  end

  def test_start_rejects_mismatched_or_optional_parameters
    collector = collector_for("RuntimeFixtures::Target#calculate", :wrong, :label)

    assert_raises(SpecProof::ConfigurationError) { collector.start }
    refute collector.enabled?
  end

  def test_start_rejects_alias_declarations
    collector = collector_for("RuntimeFixtures::Target#calculate_alias", :value, :label)

    assert_raises(SpecProof::ConfigurationError) { collector.start }
    refute collector.enabled?
  end

  def test_start_rejects_distinct_target_names_for_the_same_runtime_binding
    collector = SpecProof::Collector.new(
      specifications: [
        spec("RuntimeFixtures::Target#calculate", :value, :label),
        spec("RuntimeFixturesAlias#calculate", :value, :label)
      ],
      observer: @observer
    )

    error = assert_raises(SpecProof::ConfigurationError) { collector.start }

    assert_equal "duplicate_binding", error.code
    refute collector.enabled?
  end

  def test_start_rejects_methods_without_a_ruby_source_location
    collector = collector_for("String#length")

    assert_raises(SpecProof::ConfigurationError) { collector.start }
    refute collector.enabled?
  end

  def test_observes_define_method_target_with_required_parameters
    collector = collector_for("RuntimeFixtures::Dynamic#run", :value)
    collector.start
    assert_equal 14, RuntimeFixtures::Dynamic.new.run(14)
    collector.stop

    assert_equal [["RuntimeFixtures::Dynamic#run", { value: 14 }]], @observer.calls
    assert_empty collector.issues
  end

  def test_nonprimitive_arguments_disable_only_the_affected_target_and_are_not_inspected
    poison = Object.new
    def poison.nil?
      raise "must not inspect argument"
    end

    def poison.is_a?(*)
      raise "must not inspect argument"
    end

    def poison.to_json(*)
      raise "must not inspect argument"
    end
    @collector = SpecProof::Collector.new(
      specifications: [spec("RuntimeFixtures::Target#calculate", :value, :label)],
      observer: @observer
    )
    @collector.start

    result = RuntimeFixtures::Target.new.calculate(poison, label: :opaque)
    next_result = RuntimeFixtures::Target.new.calculate(2, label: :still_app_works)
    @collector.stop

    assert_same poison, result.first
    assert_equal [2, :still_app_works], next_result
    assert_empty @observer.calls
    assert_equal(["non_primitive_argument"], @collector.issues.map { |issue| issue[:code] })
  end

  def test_disables_only_the_target_with_a_nonprimitive_argument
    @collector = SpecProof::Collector.new(
      specifications: [
        spec("RuntimeFixtures::Target#calculate", :value, :label),
        spec("RuntimeFixtures::Replaced#run", :value)
      ],
      observer: @observer
    )
    @collector.start
    RuntimeFixtures::Target.new.calculate(Object.new, label: :opaque)
    RuntimeFixtures::Replaced.new.run(12)
    @collector.stop

    assert_equal [["RuntimeFixtures::Replaced#run", { value: 12 }]], @observer.calls
    assert_equal(["RuntimeFixtures::Target#calculate"], @collector.issues.map { |issue| issue[:target] })
  end

  def test_redefinition_before_stop_is_reported_as_integrity_issue
    @collector = collector_for("RuntimeFixtures::Replaced#run", :value)
    @collector.start
    RuntimeFixtures::Replaced.class_eval do
      def run(value)
        [:new, value]
      end
    end
    @collector.stop

    assert_equal(["target_redefined"], @collector.issues.map { |issue| issue[:code] })
  end

  def test_stop_reports_removed_target_constant_binding
    target = "RuntimeBindingFixtures::Original#run"
    collector = collector_for(target, :value)
    original = RuntimeBindingFixtures::Original
    collector.start
    original.new.run(5)
    RuntimeBindingFixtures.send(:remove_const, :Original)

    collector.stop

    assert_equal [[target, { value: 5 }]], @observer.calls
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_binding_changed"], issue_codes
  ensure
    restore_binding_constant(:Original, original) if original
  end

  def test_stop_reports_rebound_target_constant
    target = "RuntimeBindingFixtures::Original#run"
    collector = collector_for(target, :value)
    original = RuntimeBindingFixtures::Original
    collector.start
    original.new.run(6)
    RuntimeBindingFixtures.send(:remove_const, :Original)
    RuntimeBindingFixtures.const_set(:Original, Class.new do
      def run(value)
        value
      end
    end)

    collector.stop

    assert_equal [[target, { value: 6 }]], @observer.calls
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_binding_changed"], issue_codes
  ensure
    restore_binding_constant(:Original, original) if original
  end

  def test_stop_reports_autoloaded_target_constant_without_triggering_it
    target = "RuntimeBindingFixtures::Original#run"
    collector = collector_for(target, :value)
    original = RuntimeBindingFixtures::Original
    collector.start
    original.new.run(7)
    RuntimeBindingFixtures.send(:remove_const, :Original)
    RuntimeBindingFixtures.autoload(:Original, File.expand_path("fixtures/runtime/autoloaded.rb", __dir__))

    collector.stop

    assert_equal [[target, { value: 7 }]], @observer.calls
    assert RuntimeBindingFixtures.autoload?(:Original)
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_binding_changed"], issue_codes
  ensure
    restore_binding_constant(:Original, original) if original
  end

  def test_stop_reports_intermediate_namespace_rebound_to_non_module
    target = "RuntimeBindingFixtures::Namespace::NestedOriginal#run"
    collector = collector_for(target, :value)
    namespace = RuntimeBindingFixtures::Namespace
    collector.start
    namespace::NestedOriginal.new.run(8)
    RuntimeBindingFixtures.send(:remove_const, :Namespace)
    RuntimeBindingFixtures.const_set(:Namespace, 42)

    collector.stop

    assert_equal [[target, { value: 8 }]], @observer.calls
    issue_codes = collector.issues.map { |issue| issue[:code] }
    assert_equal ["target_binding_changed"], issue_codes
  ensure
    if namespace && RuntimeBindingFixtures.const_defined?(:Namespace, false)
      RuntimeBindingFixtures.send(:remove_const, :Namespace)
    end
    RuntimeBindingFixtures.const_set(:Namespace, namespace) if namespace
  end

  def test_redefined_method_is_not_observed_while_collection_is_active
    @collector = collector_for("RuntimeFixtures::Replaced#run", :value)
    @collector.start
    RuntimeFixtures::Replaced.class_eval do
      def run(value)
        [:new, value]
      end
    end

    assert_equal [:new, 3], RuntimeFixtures::Replaced.new.run(3)
    @collector.stop

    assert_empty @observer.calls
    assert_equal(["target_redefined"], @collector.issues.map { |issue| issue[:code] })
  end

  def test_stop_is_idempotent_and_double_start_is_rejected
    @collector.start

    assert_raises(SpecProof::ConfigurationError) { @collector.start }
    @collector.stop
    assert_nil @collector.stop
    refute @collector.enabled?
  end

  def test_rejects_optional_parameters
    collector = collector_for("RuntimeFixtures::Target#optional", :value)

    assert_raises(SpecProof::ConfigurationError) { collector.start }
    refute collector.enabled?
  end

  def test_reports_unsupported_values_without_growing_issues_per_call
    @collector.start
    target = RuntimeFixtures::Target.new
    20.times { target.calculate(Object.new, label: :opaque) }
    @collector.stop

    assert_equal 1, @collector.issues.length
  end

  private

  def spec(target, *inputs)
    Specification.new(target: target, inputs: inputs.to_h { |name| [name, Input.new(name: name)] }.freeze)
  end

  def collector_for(target, *inputs)
    SpecProof::Collector.new(specifications: [spec(target, *inputs)], observer: @observer)
  end

  def restore_binding_constant(name, value)
    RuntimeBindingFixtures.send(:remove_const, name) if RuntimeBindingFixtures.const_defined?(name, false)
    RuntimeBindingFixtures.const_set(name, value)
  end
end
