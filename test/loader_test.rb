# frozen_string_literal: true

require "test_helper"
require "tempfile"

class LoaderTest < Minitest::Test
  def test_duplicate_inputs_and_bad_options_are_located_configuration_errors
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.load([fixture("duplicate.rb")])
    end
    assert_equal "duplicate_input", error.code
    assert error.source
  end

  def test_loader_context_is_restored_after_failure
    assert_raises(SpecProof::ConfigurationError) { SpecProof.load([fixture("duplicate.rb")]) }
    # Empty declarations are invalid and must fail before their block runs.
    # Empty declarations must fail before their block runs.
    assert_raises(SpecProof::ConfigurationError) { SpecProof.define("X#y") {} } # rubocop:disable Lint/EmptyBlock
  end

  def test_nested_load_is_rejected_without_losing_outer_context
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.load([fixture("nested_load.rb")])
    end
    assert_equal "nested_load", error.code
    # Empty declarations are invalid and must fail before their block runs.
    # Empty declarations must fail before their block runs.
    assert_raises(SpecProof::ConfigurationError) { SpecProof.define("X#y") {} } # rubocop:disable Lint/EmptyBlock
  end

  def test_no_application_constant_resolution
    path = fixture("autoload_trap.rb")
    Object.autoload(:SpecProofAutoloadTrap, path)
    SpecProof.load([fixture("age_policy.rb")])
  ensure
    Object.send(:remove_const, :SpecProofAutoloadTrap) if Object.const_defined?(:SpecProofAutoloadTrap, false)
  end

  def test_configuration_failures_have_stable_codes_and_source_lines
    cases = {
      "duplicate target" => [
        <<~RUBY, "duplicate_target", 2
          SpecProof.define('Example#call') { input :x, values: [1] }
          SpecProof.define('Example#call') { input :x, values: [1] }
        RUBY
      ],
      "duplicate partition" => [
        <<~RUBY, "duplicate_partition", 4
          SpecProof.define('Example#call') do
            input :x, range: 0..2 do
              partition :a, range: 0..1
              partition :a, range: 1..2
            end
          end
        RUBY
      ],
      "both domain forms" => ["SpecProof.define('Example#call') do\n  input :x, range: 0..2, values: [1]\nend",
                              "domain_required", 2],
      "unknown option" => ["SpecProof.define('Example#call') do\n  input :x, values: [1], guessed: true\nend",
                           "unknown_option", 2],
      "bad flag" => ["SpecProof.define('Example#call') do\n  input :x, values: [1], exhaustive: 1\nend",
                     "invalid_flag", 2],
      "empty promised family" => ["SpecProof.define('Example#call') do\n  input :x, range: 0..2, disjoint: true\nend",
                                  "empty_partition_family", 2],
      "wrong partition kind" => [
        <<~RUBY, "partition_domain_kind", 3
          SpecProof.define('Example#call') do
            input :x, range: 0..2 do
              partition :a, values: [1]
            end
          end
        RUBY
      ]
    }

    cases.each_value do |content, code, line|
      error = assert_configuration_error(content)
      assert_equal code, error.code
      assert_equal line, error.source.line
      assert_equal @last_spec_path, error.source.path
    end
  end

  def test_readable_partition_policies_map_to_legacy_input_fields
    {
      "allow_gaps: false, allow_overlaps: false" => [true, true],
      "allow_gaps: false, allow_overlaps: true" => [true, false],
      "allow_gaps: true, allow_overlaps: false" => [false, true],
      "allow_gaps: true, allow_overlaps: true" => [false, false]
    }.each do |options, expected|
      specification = load_specification(<<~RUBY)
        SpecProof.define('Example#call') do
          input :x, range: 0..2, #{options} do
            partition :all, range: 0..2
          end
        end
      RUBY

      assert_equal expected, [specification.inputs.fetch(:x).exhaustive, specification.inputs.fetch(:x).disjoint]
    end
  end

  def test_partition_policies_default_to_permissive_and_allow_mixing_spellings
    declarations = [
      ["range: 0..2", [false, false]],
      ["range: 0..2, exhaustive: true, allow_overlaps: false", [true, true]],
      ["range: 0..2, allow_gaps: false, disjoint: true", [true, true]]
    ]

    declarations.each do |options, expected|
      specification = load_specification(<<~RUBY)
        SpecProof.define('Example#call') do
          input :x, #{options} do
            partition :all, range: 0..2
          end
        end
      RUBY

      assert_equal expected, [specification.inputs.fetch(:x).exhaustive, specification.inputs.fetch(:x).disjoint]
    end
  end

  def test_partition_policy_flags_require_strict_booleans
    %w[allow_gaps allow_overlaps].each do |flag|
      ["nil", '"false"', "0"].each do |value|
        error = assert_configuration_error(<<~RUBY)
          SpecProof.define('Example#call') do
            input :x, range: 0..2, #{flag}: #{value} do
              partition :all, range: 0..2
            end
          end
        RUBY

        assert_equal "invalid_flag", error.code
        assert_equal 2, error.source.line
        assert_equal @last_spec_path, error.source.path
        assert_includes error.message, flag
      end
    end
  end

  def test_duplicate_partition_policy_spellings_are_rejected
    [
      "exhaustive: true, allow_gaps: false",
      "exhaustive: false, allow_gaps: true",
      "disjoint: true, allow_overlaps: false",
      "disjoint: false, allow_overlaps: true"
    ].each do |options|
      error = assert_configuration_error(<<~RUBY)
        SpecProof.define('Example#call') do
          input :x, range: 0..2, #{options} do
            partition :all, range: 0..2
          end
        end
      RUBY

      assert_equal "duplicate_partition_policy", error.code
      assert_equal 2, error.source.line
      assert_equal @last_spec_path, error.source.path
    end
  end

  def test_empty_file_set_and_target_without_inputs_are_rejected
    empty_paths = assert_raises(SpecProof::ConfigurationError) { SpecProof.load([]) }
    assert_equal "paths_required", empty_paths.code
    error = assert_configuration_error("SpecProof.define('Example#call') {}")
    assert_equal "inputs_required", error.code
  end

  def test_exclusions_are_immutable_and_can_be_declared_before_or_after_inputs
    first = load_specification(<<~RUBY)
      SpecProof.define('Example#call') do
        exclude_input :payload, reason: "Payload contents outside file-ID scope"
        input :file_id, values: [nil, 1]
      end
    RUBY
    second = load_specification(<<~RUBY)
      SpecProof.define('Example#call') do
        input :file_id, values: [nil, 1]
        exclude_input :payload, reason: "Payload contents outside file-ID scope"
      end
    RUBY

    exclusion = first.exclusions.fetch(:payload)
    assert_equal "Payload contents outside file-ID scope", exclusion.reason
    assert exclusion.frozen?
    assert first.exclusions.frozen?
    assert_equal [exclusion.name, exclusion.reason],
                 [second.exclusions.fetch(:payload).name, second.exclusions.fetch(:payload).reason]
  end

  def test_exclusion_only_declaration_requires_mixed_loader_opt_in
    error = assert_configuration_error(<<~RUBY)
      SpecProof.define('Example#call') do
        exclude_input :payload, reason: "Payload outside scope"
      end
    RUBY
    assert_equal "inputs_required", error.code
  end

  def test_invalid_duplicate_and_overlapping_exclusions_are_rejected
    cases = [
      ["exclude_input :payload, reason: ''", "invalid_exclusion_reason"],
      ["exclude_input 'payload', reason: 'skip'", "invalid_name"],
      ["exclude_input :payload, reason: 'skip'\n  exclude_input :payload, reason: 'again'", "duplicate_exclusion"],
      ["input :payload, values: [1]\n  exclude_input :payload, reason: 'skip'", "input_exclusion_overlap"],
      ["exclude_input :payload, reason: 'skip'\n  input :payload, values: [1]", "input_exclusion_overlap"]
    ]

    cases.each do |declarations, code|
      error = assert_configuration_error("SpecProof.define('Example#call') do\n  #{declarations}\nend")
      assert_equal code, error.code
    end
  end

  private

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def assert_configuration_error(contents)
    Tempfile.create(["specproof-loader", ".rb"]) do |file|
      file.write(contents)
      file.flush
      @last_spec_path = file.path
      return assert_raises(SpecProof::ConfigurationError) { SpecProof.load([file.path]) }
    end
  end

  def load_specification(contents)
    Tempfile.create(["specproof-loader", ".rb"]) do |file|
      file.write(contents)
      file.flush
      return SpecProof.load([file.path]).fetch(0)
    end
  end
end
