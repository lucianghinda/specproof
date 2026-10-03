# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

class SuggestionsCliTest < Minitest::Test
  PAIRWISE = "pairwise-finite-v1"
  REPORT_LIMIT = 32 * 1024 * 1024

  def setup
    @directory = Dir.mktmpdir("specproof suggestions ")
    @spec_path = File.join(@directory, "spec with spaces.rb")
    @report_path = File.join(@directory, "coverage report.json")
    File.write(@spec_path, <<~SPEC)
      SpecProof.define "SuggestionTarget#call" do
        input :left, values: ["a", "b"]
        input :right, values: ["a b", "c"]
        input :context, values: [:x, :y]
        combinations :left, :right, all_allowed: true
      end
    SPEC
    run_coverage(observations: [["a", "a b", :x]], fail_assertion: true)
  end

  def teardown
    FileUtils.remove_entry(@directory) if @directory && File.exist?(@directory)
  end

  def test_json_suggestions_preserve_source_failure_and_identify_group_scope
    original_specification = File.binread(@spec_path)
    original_report = File.binread(@report_path)

    first_out, first_err, first_status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")
    second_out, second_err, second_status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert first_status.success?, first_err
    assert second_status.success?, second_err
    assert_equal first_out, second_out
    assert_empty first_err
    document = JSON.parse(first_out)
    assert_equal "suggestions", document.fetch("kind")
    assert_empty document.fetch("errors")
    assert_equal PAIRWISE, document.fetch("criterion")
    assert_equal "greedy-pairwise-v1", document.fetch("strategy")
    assert_equal "combination_group", document.fetch("assignment_scope")
    assert_equal "not_guaranteed", document.fetch("minimality")
    assert_equal false, document.fetch("source_tests_passed")
    assert_match(/\A[[:alnum:]-]+\z/, document.fetch("source_run_id"))
    source_input_scope = document.fetch("source_scope").fetch("input_scope")
    assert_equal 1, source_input_scope.length
    assert_equal 2, source_input_scope.first.fetch("combination_group").fetch("inputs").length
    assert_equal ["context"], document.fetch("suggestions").first.fetch("unassigned_inputs")
    assert_equal({ "left" => { "kind" => "string", "value" => "a" },
                   "right" => { "kind" => "string", "value" => "c" } },
                 document.fetch("suggestions").first.fetch("inputs"))
    assert_equal original_specification, File.binread(@spec_path)
    assert_equal original_report, File.binread(@report_path)
  end

  def test_valid_report_with_no_missing_obligations_returns_empty_success
    run_coverage(observations: [["a", "a b", :x], ["a", "c", :y], ["b", "a b", :y], ["b", "c", :x]])

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert status.success?, stderr
    assert_empty stderr
    document = JSON.parse(stdout)
    assert_equal 0, document.fetch("missing_obligation_count")
    assert_equal 0, document.fetch("suggestion_count")
    assert_empty document.fetch("suggestions")
  end

  def test_human_output_marks_rows_as_unexecuted_and_quotes_strings
    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path)

    assert status.success?, stderr
    assert_empty stderr
    assert_includes stdout, "Source run:"
    assert_includes stdout, "Source tests: failed"
    assert_includes stdout, "left=\"b\""
    assert_includes stdout, "right=\"a b\""
    assert_includes stdout, "Unassigned inputs: context"
    assert_includes stdout, "These suggestions have not been executed"
    assert_includes stdout, "No expected results are provided"
    refute_includes stdout, "minimal set"
  end

  def test_filtered_source_run_scope_is_retained_in_json_output
    run_coverage(observations: [["a", "a b", :x]], arguments: ["--name", "/test_observation/"])

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert status.success?, stderr
    scope = JSON.parse(stdout).fetch("source_scope")
    assert_equal ["--name", "/test_observation/"], scope.fetch("arguments")
    assert_equal "/test_observation/", scope.fetch("filter")
  end

  def test_report_is_required_once_and_only_for_suggest
    missing_out, _missing_err, missing_status = invoke("suggest", @spec_path, "--format", "json")
    duplicate_out, _duplicate_err, duplicate_status = invoke(
      "suggest", @spec_path, "--report", @report_path, "--report", @report_path, "--format", "json"
    )
    criterion_out, _criterion_err, criterion_status = invoke(
      "suggest", @spec_path, "--criterion", PAIRWISE, "--report", @report_path, "--format", "json"
    )
    check_out, _check_err, check_status = invoke("check", @spec_path, "--report", @report_path, "--format", "json")
    plan_out, _plan_err, plan_status = invoke("plan", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 2, missing_status.exitstatus
    assert_equal "missing_coverage_report", JSON.parse(missing_out).fetch("errors").first.fetch("code")
    assert_equal 2, duplicate_status.exitstatus
    assert_equal "duplicate_coverage_report", JSON.parse(duplicate_out).fetch("errors").first.fetch("code")
    assert_equal 2, criterion_status.exitstatus
    assert_equal "unsupported_option", JSON.parse(criterion_out).fetch("errors").first.fetch("code")
    assert_equal 2, check_status.exitstatus
    assert_equal "unsupported_option", JSON.parse(check_out).fetch("errors").first.fetch("code")
    assert_equal 2, plan_status.exitstatus
    assert_equal "unsupported_option", JSON.parse(plan_out).fetch("errors").first.fetch("code")
  end

  def test_malformed_report_json_is_a_single_invalid_coverage_error
    File.write(@report_path, "{ broken")

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 2, status.exitstatus
    assert_empty stderr
    payload = JSON.parse(stdout)
    assert_equal "suggestions", payload.fetch("kind")
    assert_equal "invalid_coverage_report", payload.fetch("errors").first.fetch("code")
    assert_empty payload.fetch("suggestions") if payload.key?("suggestions")
  end

  def test_empty_report_file_is_a_single_invalid_coverage_error
    File.write(@report_path, "")

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 2, status.exitstatus
    assert_empty stderr
    payload = JSON.parse(stdout)
    assert_equal "suggestions", payload.fetch("kind")
    assert_equal "invalid_coverage_report", payload.fetch("errors").first.fetch("code")
  end

  def test_report_over_limit_is_rejected_without_unbounded_read
    File.open(@report_path, "wb") { |file| file.truncate(REPORT_LIMIT + 1) }

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 2, status.exitstatus
    assert_empty stderr
    assert_equal "suggestion_limit_exceeded", JSON.parse(stdout).fetch("errors").first.fetch("code")
  end

  def test_contract_mismatch_is_atomic_json_configuration_error
    report = JSON.parse(File.read(@report_path))
    report["contract_digest"] = "stale"
    File.write(@report_path, JSON.generate(report))

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 2, status.exitstatus
    assert_empty stderr
    payload = JSON.parse(stdout)
    assert_equal "coverage_contract_mismatch", payload.fetch("errors").first.fetch("code")
    refute payload.key?("suggestions")
  end

  def test_semantic_specification_findings_exit_one_without_suggestions
    File.write(@spec_path, <<~SPEC)
      SpecProof.define "SuggestionTarget#call" do
        input :left, values: [1, 2, 3], exhaustive: true, disjoint: false do
          partition :lower, values: [1]
          partition :upper, values: [3]
        end
        input :right, values: [false, true]
        combinations :left, :right, all_allowed: true
      end
    SPEC

    stdout, stderr, status = invoke("suggest", @spec_path, "--report", @report_path, "--format", "json")

    assert_equal 1, status.exitstatus, "#{stdout}\n#{stderr}"
    assert_empty stderr
    payload = JSON.parse(stdout)
    assert_equal "suggestions", payload.fetch("kind")
    assert_equal "partition_gap", payload.fetch("findings").first.fetch("code")
    refute payload.key?("suggestions")
  end

  private

  def run_coverage(observations:, fail_assertion: false, arguments: [])
    script = <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"
      class SuggestionTarget
        def call(left, right, context)
          [left, right, context]
        end
      end
      class SuggestionsCliSourceTest < Minitest::Test
        def test_observation
          #{observations.map { |left, right, context| "SuggestionTarget.new.call(#{left.inspect}, #{right.inspect}, #{context.inspect})" }.join("\n          ")}
          assert false if #{fail_assertion}
        end
      end
      require "specproof/minitest"
      SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], criterion: #{PAIRWISE.inspect},
                                   output: ENV.fetch("REPORT_PATH"))
    RUBY
    env = {
      "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil, "MT_NO_PLUGINS" => "1",
      "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
      "SPEC_PATH" => @spec_path, "REPORT_PATH" => @report_path
    }
    argv = arguments.empty? ? [] : ["--", *arguments]
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, "-e", script, *argv, chdir: @directory)
    assert File.file?(@report_path), stderr
    # An assertion failure is intentional evidence for the suggestion workflow.
    assert_equal fail_assertion ? 1 : 0, status.exitstatus,
                 "#{stdout}\n#{stderr}\n#{File.read(@report_path)}"
  end

  def invoke(*)
    Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "-Ilib", "exe/specproof", *,
                   chdir: File.expand_path("..", __dir__))
  end
end
