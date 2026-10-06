# frozen_string_literal: true

require "test_helper"

class TargetNameTest < Minitest::Test
  class DeliveryOptions
    def build(value)
      value
    end

    def self.build(value)
      value
    end
  end

  module ModuleTarget
    def self.build(value)
      value
    end
  end

  class InvalidReceiver
    def call; end
  end

  class InvalidSingletonTarget
    def self.current; end
    class << self
      alias alternate current
      private :current
    end
  end

  class SingletonParent
    def self.inherited_method; end
  end

  class SingletonChild < SingletonParent
  end

  OwnerNamespace = Module.new do
    const_set(:Nested, Class.new do
      def run; end
    end)
  end

  def test_instance_method_normalizes_to_its_canonical_target
    assert_equal "TargetNameTest::DeliveryOptions#build",
                 SpecProof::TargetName.normalize(DeliveryOptions.instance_method(:build))
  end

  def test_singleton_method_normalizes_to_its_canonical_target
    assert_equal "TargetNameTest::DeliveryOptions.build",
                 SpecProof::TargetName.normalize(DeliveryOptions.method(:build))
    assert_equal "TargetNameTest::ModuleTarget.build",
                 SpecProof::TargetName.normalize(ModuleTarget.method(:build))
  end

  def test_parse_returns_owner_method_and_kind
    assert_equal ["DeliveryOptions", :build, :instance], SpecProof::TargetName.parse("DeliveryOptions#build")
    assert_equal ["DeliveryOptions", :build, :singleton], SpecProof::TargetName.parse("DeliveryOptions.build")
  end

  def test_strings_are_validated_without_resolving_constants
    Object.autoload(:TargetNameAutoloadTrap, File.expand_path("fixtures/runtime/autoloaded.rb", __dir__))

    assert_equal "TargetNameAutoloadTrap#call", SpecProof::TargetName.normalize("TargetNameAutoloadTrap#call")
    assert Object.autoload?(:TargetNameAutoloadTrap)
  ensure
    Object.send(:remove_const, :TargetNameAutoloadTrap) if Object.autoload?(:TargetNameAutoloadTrap)
  end

  def test_loader_stores_normalized_targets_and_rejects_equivalent_duplicates
    specification = load_expression("TargetNameTest::DeliveryOptions.instance_method(:build)")
    assert_equal "TargetNameTest::DeliveryOptions#build", specification.target

    error = assert_raises(SpecProof::ConfigurationError) do
      load_declarations(<<~RUBY)
        SpecProof.define("TargetNameTest::DeliveryOptions#build") { input :value, values: [1] }
        SpecProof.define(TargetNameTest::DeliveryOptions.instance_method(:build)) { input :value, values: [1] }
      RUBY
    end
    assert_equal "duplicate_target", error.code
    assert error.source
  end

  def test_method_object_and_string_have_identical_plans_and_contract_digests
    [
      ["TargetNameTest::DeliveryOptions#build", "TargetNameTest::DeliveryOptions.instance_method(:build)"],
      ["TargetNameTest::DeliveryOptions.build", "TargetNameTest::DeliveryOptions.method(:build)"],
      ["TargetNameTest::ModuleTarget.build", "TargetNameTest::ModuleTarget.method(:build)"]
    ].each do |string_target, method_expression|
      string_specification = load_declarations(<<~RUBY).fetch(0)
        SpecProof.define(#{string_target.inspect}) { input :value, values: [1] }
      RUBY
      object_specification = load_expression(method_expression)

      assert_equal SpecProof.plan([string_specification]).map(&:id), SpecProof.plan([object_specification]).map(&:id)
      assert_equal SpecProof::Report.digest([string_specification]), SpecProof::Report.digest([object_specification])
    end
  end

  def test_instance_and_singleton_targets_keep_distinct_plan_ids
    specifications = load_declarations(<<~RUBY)
      SpecProof.define("TargetNameTest::DeliveryOptions#build") { input :value, values: [1] }
      SpecProof.define("TargetNameTest::DeliveryOptions.build") { input :value, values: [1] }
    RUBY

    assert_equal ["TargetNameTest::DeliveryOptions#build", "TargetNameTest::DeliveryOptions.build"],
                 specifications.map(&:target)
    refute_equal SpecProof.plan([specifications[0]]).map(&:id), SpecProof.plan([specifications[1]]).map(&:id)
  end

  def test_invalid_method_objects_are_rejected_with_configuration_source
    error = assert_raises(SpecProof::ConfigurationError) do
      load_expression("TargetNameTest::InvalidReceiver.new.method(:call)")
    end
    assert_equal "invalid_target", error.code
    assert error.source
  end

  def test_anonymous_method_owners_are_rejected
    anonymous_method = Class.new do
      def run; end
    end.instance_method(:run)

    error = assert_raises(SpecProof::ConfigurationError) { SpecProof::TargetName.normalize(anonymous_method) }
    assert_equal "invalid_target", error.code
  end

  def test_rebound_non_module_owner_namespace_is_rejected
    namespace = OwnerNamespace
    owner = OwnerNamespace::Nested.instance_method(:run)
    TargetNameTest.send(:remove_const, :OwnerNamespace)
    TargetNameTest.const_set(:OwnerNamespace, 1)

    error = assert_raises(SpecProof::ConfigurationError) { SpecProof::TargetName.normalize(owner) }
    assert_equal "invalid_target", error.code
  ensure
    TargetNameTest.send(:remove_const, :OwnerNamespace) if TargetNameTest.const_defined?(:OwnerNamespace, false)
    TargetNameTest.const_set(:OwnerNamespace, namespace)
  end

  def test_malformed_string_target_keeps_its_dsl_source
    error = assert_raises(SpecProof::ConfigurationError) { load_declarations('SpecProof.define("invalid") {}') }

    assert_equal "invalid_target", error.code
    assert_equal 1, error.source.line
  end

  def test_aliases_stale_methods_and_private_singleton_methods_are_rejected
    old_method = DeliveryOptions.instance_method(:build)
    DeliveryOptions.class_eval do
      def build(value)
        value.to_s
      end
    end
    TargetNameTest.const_set(:STALE_METHOD, old_method)

    [
      "TargetNameTest::InvalidSingletonTarget.method(:alternate)",
      "TargetNameTest::InvalidSingletonTarget.singleton_class.instance_method(:current).bind(TargetNameTest::InvalidSingletonTarget)",
      "TargetNameTest::STALE_METHOD",
      "String.method(:new)",
      "Math.method(:sqrt)",
      "TargetNameTest::SingletonChild.method(:inherited_method)"
    ].each do |expression|
      error = assert_raises(SpecProof::ConfigurationError) { load_expression(expression) }
      assert_equal "invalid_target", error.code
      assert error.source
    end
  ensure
    DeliveryOptions.class_eval do
      def build(value)
        value
      end
    end
    TargetNameTest.send(:remove_const, :STALE_METHOD) if TargetNameTest.const_defined?(:STALE_METHOD, false)
  end

  private

  def load_expression(expression)
    load_declarations("SpecProof.define(#{expression}) { input :value, values: [1] }").fetch(0)
  end

  def load_declarations(contents)
    require "tempfile"
    Tempfile.create(["specproof-target", ".rb"]) do |file|
      file.write(contents)
      file.flush
      SpecProof.load([file.path])
    end
  end
end
