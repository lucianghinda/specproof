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

  def test_empty_file_set_and_target_without_inputs_are_rejected
    empty_paths = assert_raises(SpecProof::ConfigurationError) { SpecProof.load([]) }
    assert_equal "paths_required", empty_paths.code
    error = assert_configuration_error("SpecProof.define('Example#call') {}")
    assert_equal "inputs_required", error.code
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
end
