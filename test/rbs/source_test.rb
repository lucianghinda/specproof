# frozen_string_literal: true

require_relative "../test_helper"
require "specproof/sources/rbs"
require "open3"
require "rbconfig"
require "tmpdir"

class RBSSourceTest < Minitest::Test
  def test_core_and_skill_export_do_not_activate_optional_rbs
    Dir.mktmpdir("specproof-rbs-optional", "/private/tmp") do |directory|
      signature = File.join(directory, "registration.rbs")
      destination = File.join(directory, "skills")
      empty_gem_path = File.join(directory, "empty-gems")
      Dir.mkdir(empty_gem_path)
      File.write(signature, "class Registration\n def save: (Integer value) -> void\nend\n")
      script = <<~RUBY
        require "specproof/sources/rbs"
        abort "core loaded RBS" if defined?(::RBS)
        exported = SpecProof::Skills.export(to: ENV.fetch("SKILL_DESTINATION"))
        abort "skills did not export" if exported.fetch(:exported).empty?
        begin
          SpecProof::Sources::RBS.load(paths: [ENV.fetch("RBS_PATH")], targets: ["Registration#save"])
        rescue SpecProof::ConfigurationError => error
          abort error.code unless error.code == "rbs_dependency_missing"
          puts error.code
        end
      RUBY
      environment = {
        "RUBYOPT" => nil,
        "RUBYLIB" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_LOCKFILE" => nil,
        "BUNDLE_PATH" => nil,
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLER_SETUP" => nil,
        "BUNDLER_VERSION" => nil,
        "GEM_HOME" => empty_gem_path,
        "GEM_PATH" => empty_gem_path,
        "RBS_PATH" => signature,
        "SKILL_DESTINATION" => destination
      }
      stdout, stderr, status = Open3.capture3(
        environment, RbConfig.ruby, "-I#{File.expand_path("../../lib", __dir__)}", "-e", script
      )

      assert status.success?, stderr + stdout
      assert_equal "rbs_dependency_missing\n", stdout
      assert File.file?(File.join(destination, "specproof-specify", "SKILL.md"))
    end
  end

  def test_loads_named_scalar_inputs_from_direct_public_instance_signatures
    path = File.expand_path("../fixtures/rbs/registration.rbs", __dir__)
    facts = SpecProof::Sources::RBS.load(
      paths: [path], targets: ["Registration#initialize", "Registration#update", "Registration#maybe",
                               "Registration#trailing"]
    )

    assert_equal ["Registration#initialize", "Registration#initialize", "Registration#maybe", "Registration#trailing",
                  "Registration#trailing", "Registration#trailing", "Registration#trailing", "Registration#trailing",
                  "Registration#update", "Registration#update"], facts.map(&:target)
    constraints = facts.map do |fact|
      [fact.input, fact.constraint.integer_any, fact.constraint.values]
    end
    assert_equal [[:age, true, []], [:consent, false, [false, true]], [:value, false, [nil, false, true]],
                  [:first, true, []], [:flag, false, [false, true]], [:last, true, []],
                  [:maybe, false, [false, true]], [:required, false, %i[one two]],
                  [:age, true, []], [:mode, false, %i[fast safe]]], constraints
    assert facts.frozen?
    assert(facts.all? { |fact| fact.frozen? && fact.source.frozen? && fact.constraint.frozen? })
    assert(facts.all? { |fact| fact.source.kind == "rbs" })
    assert_equal path, facts.first.source.path
    assert_equal 2, facts.first.source.line
  end

  def test_loads_class_and_module_singleton_methods_and_keeps_instance_names_distinct
    path = File.expand_path("../fixtures/rbs/method_object_targets.rbs", __dir__)
    facts = SpecProof::Sources::RBS.load(
      paths: [path], targets: ["RBSDelivery#build", "RBSDelivery.build", "RBSRegistry.fetch"]
    )

    assert_equal ["RBSDelivery#build", "RBSDelivery.build", "RBSRegistry.fetch"], facts.map(&:target).uniq
    actual = facts.map do |fact|
      [fact.input, fact.constraint.integer_any, fact.constraint.values]
    end.take(2)
    assert_equal [[:quantity, false, ["ready"]], [:quantity, true, []]], actual
    assert_equal [:id], facts.select { |fact| fact.target == "RBSRegistry.fetch" }.map(&:input)
  end

  def test_composes_rbs_singleton_facts_with_dsl_declarations
    with_rbs("class RBSDelivery\n def self.build: (Integer quantity) -> void\nend\n") do |rbs_path|
      with_spec("SpecProof.define(\"RBSDelivery.build\") { input :quantity, range: 1..3 }\n") do |spec_path|
        specifications = SpecProof.load([spec_path], rbs: [rbs_path], targets: ["RBSDelivery.build"])

        assert_equal ["RBSDelivery.build"], specifications.map(&:target)
        assert_equal [:quantity], specifications.fetch(0).inputs.keys
        assert_equal true, specifications.fetch(0).inputs.fetch(:quantity).type_constraint.integer_any
      end
    end
  end

  def test_rejects_singleton_aliases_and_duplicate_reopenings
    contents = "class RBSDelivery\n alias self.copy self.build\n def self.build: (Integer quantity) -> void\nend\n"
    with_rbs(contents) do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSDelivery.copy"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "method aliases"
    end

    with_rbs("class RBSDelivery\n def self.build: (Integer quantity) -> void\nend\n" \
             "class RBSDelivery\n def self.build: (Integer quantity) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSDelivery.build"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "more than once"
    end
  end

  def test_rejects_private_singleton_methods_and_module_instance_methods
    with_rbs("class RBSDelivery\n private def self.build: (Integer quantity) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSDelivery.build"])
      end
      assert_equal "unsupported_rbs_signature", error.code
    end

    with_rbs("module RBSRegistry\n def fetch: (Integer id) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSRegistry#fetch"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "module owners"
    end
  end

  def test_rejects_singleton_instance_and_unsupported_singleton_signatures
    with_rbs("class RBSDelivery\n def self?.build: (Integer quantity) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSDelivery.build"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "singleton_instance"
    end

    signatures = [["(Object quantity)", "unsupported_rbs_type"], ["[A] (A quantity)", "unsupported_rbs_signature"]]
    signatures.each do |signature, code|
      with_rbs("class RBSDelivery\n def self.build: #{signature} -> void\nend\n") do |path|
        error = assert_raises(SpecProof::ConfigurationError) do
          SpecProof::Sources::RBS.load(paths: [path], targets: ["RBSDelivery.build"])
        end
        assert_equal code, error.code
      end
    end
  end

  def test_resolves_absolute_integer_and_nested_class_names
    facts = with_rbs(<<~RBS) do |path|
      module Shop
        class Integer
        end
        class Cart
          def add: (::Integer count) -> void
        end
      end
    RBS
      SpecProof::Sources::RBS.load(paths: [path], targets: ["Shop::Cart#add"])
    end

    assert_equal true, facts.fetch(0).constraint.integer_any
  end

  def test_maps_supported_literal_and_union_types
    signatures = {
      "nil literal" => ["nil", [nil]],
      "integer literal" => ["1", [1]],
      "boolean literal" => ["true", [true]],
      "symbol literal" => [":ready", [:ready]],
      "nullable integer" => ["Integer?", [nil]],
      "symbol and integer union" => ["Integer | :ready", [:ready]],
      "integer and string literal union" => ['Integer | "ready"', ["ready"]],
      "string literal" => ['"ready"', ["ready"]],
      "string literal union" => ['"ready" | "done"', %w[done ready]],
      "nilable string literal" => ['"ready"?', [nil, "ready"]],
      "mixed literal union" => ['"ready" | :ready', [:ready, "ready"]],
      "duplicate string literals" => ['"ready" | "ready"', ["ready"]],
      "empty string literal" => ['""', [""]],
      "whitespace string literal" => ['" \t"', [" \t"]]
    }

    signatures.each do |description, (type, expected_values)|
      facts = with_rbs("class Registration\n def save: (#{type} value) -> void\nend\n") do |path|
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      fact = facts.fetch(0)
      assert_equal expected_values, fact.constraint.values, description
      assert_equal(type.include?("Integer"), fact.constraint.integer_any, description)
    end
  end

  def test_canonicalizes_decoded_rbs_string_literals_without_changing_their_values
    contents = ["class Registration", '  def save: ("é" | "\u00e9" value) -> void', "end", ""].join("\n")
    original_encoding = Encoding.default_external
    Encoding.default_external = Encoding::US_ASCII
    begin
      facts = with_rbs(contents) do |path|
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
    ensure
      Encoding.default_external = original_encoding
    end

    values = facts.fetch(0).constraint.values
    assert_equal ["é"], values
    value = values.fetch(0)
    assert_equal Encoding::UTF_8, value.encoding
    assert value.frozen?
    assert_equal 2, facts.fetch(0).source.line
  end

  def test_string_literal_union_order_preserves_contract_ids_and_digest
    first = with_rbs("class Registration\n def save: (\"ready\" | \"done\" value) -> void\nend\n") do |path|
      SpecProof.load([], rbs: [path], targets: ["Registration#save"])
    end
    reversed = with_rbs("class Registration\n def save: (\"done\" | \"ready\" value) -> void\nend\n") do |path|
      SpecProof.load([], rbs: [path], targets: ["Registration#save"])
    end

    assert_equal SpecProof::Report.digest(first), SpecProof::Report.digest(reversed)
    assert_equal SpecProof.plan(first).map(&:id), SpecProof.plan(reversed).map(&:id)
  end

  def test_string_literal_union_refinement_accepts_subsets_and_reports_conflicts
    Dir.mktmpdir("specproof-rbs-string-refinement", "/private/tmp") do |directory|
      policy = File.join(directory, "policy.rb")
      File.write(policy, <<~RUBY)
        SpecProof.define "Registration#save" do
          input :value, values: [1, "ready"]
        end
      RUBY
      narrowed = with_rbs("class Registration\n def save: (Integer | \"ready\" value) -> void\nend\n") do |path|
        SpecProof.load([policy], rbs: [path], targets: ["Registration#save"])
      end
      assert_empty SpecProof.check(narrowed)

      File.write(policy, <<~RUBY)
        SpecProof.define "Registration#save" do
          input :value, values: [1, "outside"]
        end
      RUBY
      conflicting = with_rbs("class Registration\n def save: (Integer | \"ready\" value) -> void\nend\n") do |path|
        SpecProof.load([policy], rbs: [path], targets: ["Registration#save"])
      end
      finding = SpecProof.check(conflicting).fetch(0)
      assert_equal :type_domain_conflict, finding.code
      assert_equal "outside", finding.witness
    end
  end

  def test_rejects_unsupported_types_atomically
    types = {
      "unrestricted string" => "String",
      "unrestricted string and literal union" => 'String | "ready"',
      "string literal and unsupported union" => '"ready" | Object',
      "untyped" => "untyped",
      "type alias" => "flag",
      "unknown nominal" => "MissingType",
      "array" => "Array[bool]",
      "record" => "{ name: bool }",
      "intersection" => "bool & Integer"
    }

    types.each do |description, type|
      contents = "type flag = bool\nclass Registration\n def save: (Integer age, #{type} value) -> void\nend\n"
      with_rbs(contents) do |path|
        error = assert_raises(SpecProof::ConfigurationError, description) do
          SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
        end
        assert_equal "unsupported_rbs_type", error.code, description
        assert_includes error.message, "input value", description
      end
    end

    with_rbs("class Registration\n def save: (Integer age, (bool | Object) value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_type", error.code
      assert_includes error.message, "input value"
    end
  end

  def test_uses_input_location_and_ignores_metadata_annotations
    facts = with_rbs(<<~RBS) do |path|
      class Registration
        # @deprecated Retained for an old caller.
        def save: (
          Integer value
        ) -> void
      end
    RBS
      SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
    end

    assert_equal 4, facts.fetch(0).source.line
    assert facts.fetch(0).source.path.end_with?("/types.rbs")
  end

  def test_rejects_invalid_utf8_signature_content_with_rbs_parse_error
    Dir.mktmpdir("specproof-rbs-invalid-utf8", "/private/tmp") do |directory|
      path = File.join(directory, "types.rbs")
      content = "class Registration\n def save: (\"".b + [0xFF].pack("C") + "\" value) -> void\nend\n".b
      File.binwrite(path, content)

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end

      assert_equal "rbs_parse_error", error.code
      assert_equal path, error.path
      assert error.message.ascii_only?
    end
  end

  def test_rejects_missing_target_and_unsupported_selected_type
    with_rbs("class Registration\n def save: (Object value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#missing"])
      end
      assert_equal "rbs_target_not_found", error.code
    end

    with_rbs("class Registration\n def save: (Object value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_type", error.code
      assert_includes error.message, "Registration#save / input value"
      assert_equal "rbs", error.source.kind
    end
  end

  def test_rejects_unsupported_signature_shapes_for_selected_methods
    signatures = {
      "module owner" => ["module Registration\n def save: (Integer value) -> void\nend\n", "Registration#save"],
      "singleton" => ["class Registration\n def self.save: (Integer value) -> void\nend\n", "Registration#save"],
      "private" => ["class Registration\n private\n def save: (Integer value) -> void\nend\n", "Registration#save"],
      "alias" => ["class Registration\n def old: (Integer value) -> void\n alias save old\nend\n", "Registration#save"],
      "attribute" => ["class Registration\n attr_reader save: Integer\nend\n", "Registration#save"],
      "attribute writer" => ["class Registration\n attr_accessor save: Integer\nend\n", "Registration#save="],
      "unnamed" => ["class Registration\n def save: (Integer) -> void\nend\n", "Registration#save"],
      "duplicate names" => ["class Registration\n def save: (Integer value, String value) -> void\nend\n",
                            "Registration#save"],
      "duplicate positional and keyword labels" => [
        "class Registration\n " \
        "def save: (Integer value, value: bool) -> void\n" \
        "end\n",
        "Registration#save"
      ],
      "empty inputs" => ["class Registration\n def save: () -> void\nend\n", "Registration#save"],
      "method generic" => ["class Registration\n def save: [A] (A value) -> void\nend\n", "Registration#save"],
      "class generic" => ["class Registration[A]\n def save: (Integer value) -> void\nend\n", "Registration#save"],
      "overload" => ["class Registration\n def save: (Integer value) -> void | (String value) -> void\nend\n",
                     "Registration#save"],
      "overload within method declaration" => [
        "class Registration\n def save: (Integer value) -> void\n | (String value) -> void\nend\n",
        "Registration#save"
      ],
      "extension annotation" => [
        "class Registration\n def save: %a{pure} (Integer value) -> void\nend\n",
        "Registration#save"
      ],
      "forwarding" => ["class Registration\n def save: (...) -> void\nend\n", "Registration#save"],
      "rest" => ["class Registration\n def save: (*Integer values) -> void\nend\n", "Registration#save"],
      "keyword rest" => ["class Registration\n def save: (**String options) -> void\nend\n", "Registration#save"],
      "block" => ["class Registration\n def save: (Integer value) ?{ () -> void } -> void\nend\n", "Registration#save"]
    }

    signatures.each do |description, (contents, target)|
      with_rbs(contents) do |path|
        error = assert_raises(SpecProof::ConfigurationError, description) do
          SpecProof::Sources::RBS.load(paths: [path], targets: [target])
        end
        expected_code = description == "forwarding" ? "rbs_parse_error" : "unsupported_rbs_signature"
        assert_equal expected_code, error.code, description
        assert_equal "rbs", error.source.kind, description
      end
    end
  end

  def test_explicit_visibility_overrides_context_and_inline_private_is_rejected
    with_rbs(<<~RBS) do |path|
      class Registration
        private
        public def save: (Integer value) -> void
      end
      class Registration
        private
        def hidden: (Integer value) -> void
        public
        def visible: (Integer value) -> void
      end
    RBS
      facts = SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save", "Registration#visible"])
      assert_equal ["Registration#save", "Registration#visible"], facts.map(&:target).uniq
    end

    with_rbs("class Registration\n private def save: (Integer value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
    end
  end

  def test_rejects_duplicate_method_declarations_in_one_class_declaration
    contents = "class Registration\n def save: (Integer value) -> void\n"
    contents += " def save: (Integer value) -> void\nend\n"
    with_rbs(contents) do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "more than once"
    end
  end

  def test_rejects_generic_core_owner_reopened_without_type_parameters
    with_rbs("class Array\n def enabled?: (bool flag) -> bool\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Array#enabled?"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "generic owner"
    end
  end

  def test_rejects_attribute_and_direct_instance_method_ambiguity
    with_rbs("class Registration\n attr_reader save: Integer\n def save: (Integer value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "generated attribute"
    end
  end

  def test_rejects_unsupported_rbs_version
    with_rbs("class Registration\n def save: (Integer value) -> void\nend\n") do |path|
      script = <<~RUBY
        require "rbs"
        RBS.send(:remove_const, :VERSION)
        RBS.const_set(:VERSION, "9.9.9")
        require "specproof"
        require "specproof/sources/rbs"
        begin
          SpecProof::Sources::RBS.load(paths: [ENV.fetch("RBS_PATH")], targets: ["Registration#save"])
        rescue SpecProof::ConfigurationError => error
          abort error.code unless error.code == "unsupported_rbs_version"
          puts error.code
        end
      RUBY
      environment = { "RUBYOPT" => nil, "RUBYLIB" => nil, "RBS_PATH" => path }
      stdout, stderr, status = Open3.capture3(
        environment, RbConfig.ruby, "-I#{File.expand_path("../../lib", __dir__)}", "-e", script
      )

      assert status.success?, stderr + stdout
      assert_equal "unsupported_rbs_version\n", stdout
    end
  end

  def test_rejects_shadowed_integer_and_duplicate_reopenings
    with_rbs("module Shop\n class Integer\n end\n class Cart\n def add: (Integer count) -> void\n end\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Shop::Cart#add"])
      end
      assert_equal "unsupported_rbs_type", error.code
    end

    with_rbs(<<~RBS) do |path|
      class Registration
        def save: (Integer value) -> void
      end
      class Registration
        def save: (Integer value) -> void
      end
    RBS
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "more than once"
    end

    with_rbs("class Registration[A]\nend\nclass Registration\n def save: (Integer value) -> void\nend\n") do |path|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "generic owner"
    end

    with_rbs(<<~RBS) do |path|
      class Registration
        def self.save: (Object item) -> void
        def save: (Integer value) -> void
        alias self.save self.old
      end
    RBS
      facts = SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      assert_equal [:value], facts.map(&:input)
    end

    with_rbs(<<~RBS) do |path|
      class Registration
        def old: (Integer value) -> void
        alias save old
        def save: (Integer value) -> void
      end
    RBS
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "method aliases"
    end
  end

  def test_ignores_core_and_inherited_methods_as_targets
    with_rbs("class Registration\n def own: (Integer value) -> void\nend\n") do |path|
      ["Integer#abs", "Registration#to_s"].each do |target|
        error = assert_raises(SpecProof::ConfigurationError) do
          SpecProof::Sources::RBS.load(paths: [path], targets: [target])
        end
        assert_equal "rbs_target_not_found", error.code
      end
    end
  end

  def test_rejects_nested_module_method_owners
    with_rbs(<<~RBS) do |path|
      module Shop
        module Admin
          def save: (Integer value) -> void
        end
      end
    RBS
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Shop::Admin#save"])
      end
      assert_equal "unsupported_rbs_signature", error.code
      assert_includes error.message, "module owners"
    end
  end

  def test_ignores_unsupported_unselected_signature_but_fails_malformed_file
    Dir.mktmpdir do |directory|
      path = File.join(directory, "types.rbs")
      File.write(path, <<~RBS)
        class Registration
          def save: (Integer age) -> void
        end
        class Unused
          def bad: (Object value) -> void
        end
      RBS
      facts = SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      assert_equal ["Registration#save"], facts.map(&:target)

      File.write(path, "class Registration\n def save: (\nend\n")
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save"])
      end
      assert_equal "rbs_parse_error", error.code
      assert_equal 3, error.source.line
    end
  end

  def test_rejects_invalid_arguments_duplicate_paths_targets_and_missing_files
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Sources::RBS.load(paths: [], targets: ["Registration#save"])
    end
    assert_equal "paths_required", error.code

    with_rbs("class Registration\n def save: (Integer age) -> void\nend\n") do |path|
      assert_equal "duplicate_target", assert_raises(SpecProof::ConfigurationError) {
        SpecProof::Sources::RBS.load(paths: [path], targets: ["Registration#save", "Registration#save"])
      }.code
      assert_equal "duplicate_path", assert_raises(SpecProof::ConfigurationError) {
        duplicate_path = File.join(File.dirname(path), ".", File.basename(path))
        SpecProof::Sources::RBS.load(paths: [path, duplicate_path], targets: ["Registration#save"])
      }.code
    end

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::Sources::RBS.load(paths: ["/no/such/specproof.rbs"], targets: ["Registration#save"])
    end
    assert_equal "file_not_found", error.code

    Dir.mktmpdir do |directory|
      regular_file = File.join(directory, "types.rbs")
      File.write(regular_file, "")
      directory_error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Sources::RBS.load(paths: [directory], targets: ["Registration#save"])
      end
      assert_equal "file_error", directory_error.code
      assert_includes directory_error.message, "not a regular file"

      child_error = assert_raises(SpecProof::ConfigurationError) do
        child_path = File.join(regular_file, "child", "types.rbs")
        SpecProof::Sources::RBS.load(paths: [child_path],
                                     targets: ["Registration#save"])
      end
      assert_equal "file_error", child_error.code
      assert_equal File.join(regular_file, "child", "types.rbs"), child_error.path
    end
  end

  private

  def with_rbs(content)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "types.rbs")
      File.write(path, content)
      yield path
    end
  end

  def with_spec(content)
    Dir.mktmpdir do |directory|
      path = File.join(directory, "specification.rb")
      File.write(path, content)
      yield path
    end
  end
end
