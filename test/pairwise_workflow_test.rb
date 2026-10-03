# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

class PairwiseWorkflowTest < Minitest::Test
  PAIRWISE = "pairwise-finite-v1"

  def test_observations_from_separate_calls_do_not_form_a_pair
    specifications = SpecProof.load([fixture("pairwise.rb")])
    obligations = SpecProof.plan(specifications, criterion: PAIRWISE)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    coverage.observe(target: "Pairwise#call", arguments: { a: false, b: false, c: false })
    coverage.observe(target: "Pairwise#call", arguments: { a: true, b: true, c: true })

    report = coverage.to_report
    assert_equal 6, report.fetch(:exercised_count)
    assert_equal 6, report.fetch(:missing_count)
    assert_equal 12, report.fetch(:obligation_count)
    assert(report.fetch(:missing).any? { |item| pair_values(item) == [false, true] })
    refute(report.fetch(:exercised).any? { |item| pair_values(item) == [false, true] })
  end

  def test_four_full_tuples_can_cover_every_pair_for_three_boolean_inputs
    specifications = SpecProof.load([fixture("pairwise.rb")])
    obligations = SpecProof.plan(specifications, criterion: PAIRWISE)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    [
      { a: false, b: false, c: false },
      { a: false, b: true, c: true },
      { a: true, b: false, c: true },
      { a: true, b: true, c: false }
    ].each { |arguments| coverage.observe(target: "Pairwise#call", arguments: arguments) }

    report = coverage.to_report
    assert_equal 12, report.fetch(:exercised_count)
    assert_equal 0, report.fetch(:missing_count)
    assert_equal 100.0, report.fetch(:completion_percent)
  end

  def test_joint_forbidden_call_fulfills_no_pair_and_is_reported_separately
    specifications = SpecProof.load([fixture("pairwise_constrained.rb")])
    obligations = SpecProof.plan(specifications, criterion: PAIRWISE)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    refute coverage.observe(target: "ConstrainedPairwise#call", arguments: { a: true, b: false })

    report = coverage.to_report
    assert_equal obligations.length, report.fetch(:missing_count)
    assert_equal 1, report.fetch(:outside_domain).fetch("ConstrainedPairwise#call").fetch(:count)
    outside_combinations = report.fetch(:outside_combinations)
    assert_equal 1, outside_combinations.fetch("ConstrainedPairwise#call").fetch(:count)
    assert_equal({ "a" => { kind: "boolean", value: true }, "b" => { kind: "boolean", value: false } },
                 outside_combinations.fetch("ConstrainedPairwise#call").fetch(:witness))
  end

  def test_forbidden_triple_does_not_hit_its_individually_feasible_pairs
    Dir.mktmpdir("specproof-forbidden-triple") do |directory|
      specifications = load_forbidden_triple(directory)
      obligations = SpecProof.plan(specifications, criterion: PAIRWISE)
      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
      forbidden = { a: true, b: false, c: false }

      space = SpecProof::CombinationSpace.new(specifications.first)
      refute space.allowed?(forbidden)
      [
        { a: true, b: false },
        { a: true, c: false },
        { b: false, c: false }
      ].each { |pair| assert_includes space.pairs, pair }
      refute coverage.observe(target: "ForbiddenTriple#call", arguments: forbidden)

      report = coverage.to_report
      assert_equal obligations.length, report.fetch(:missing_count)
      assert_equal 1, report.fetch(:outside_combinations).fetch("ForbiddenTriple#call").fetch(:count)
      assert_equal 1, report.fetch(:outside_domain).fetch("ForbiddenTriple#call").fetch(:count)
    end
  end

  def test_scalar_criterion_rejects_a_jointly_forbidden_tuple_before_any_hit
    Dir.mktmpdir("specproof-forbidden-scalar") do |directory|
      specifications = load_forbidden_triple(directory)
      obligations = SpecProof.plan(specifications)
      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

      refute coverage.observe(target: "ForbiddenTriple#call", arguments: { a: true, b: false, c: false })

      report = coverage.to_report
      assert_equal obligations.length, report.fetch(:missing_count)
      assert_equal 0, report.fetch(:exercised_count)
      assert_equal 1, report.fetch(:outside_domain).fetch("ForbiddenTriple#call").fetch(:count)
      assert_equal 1, report.fetch(:outside_combinations).fetch("ForbiddenTriple#call").fetch(:count)
    end
  end

  def test_cli_pairwise_plan_serializes_typed_pairs_and_excluded_pairs
    stdout, stderr, status = invoke("plan", fixture("pairwise_constrained.rb"), "--criterion", PAIRWISE,
                                    "--format", "json")

    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal PAIRWISE, report.fetch("criterion")
    assert_equal 3, report.fetch("obligations").length
    assert_equal %w[a b], report.fetch("obligations").first.fetch("inputs").keys
    assert_equal "boolean", report.fetch("obligations").first.fetch("inputs").fetch("a").fetch("kind")
    excluded = report.fetch("excluded_pairs")
    assert_equal 1, excluded.length
    assert_equal "no_allowed_completion", excluded.first.fetch("reason")
    assert_equal 4, excluded.first.fetch("sources").length
  end

  def test_check_rejects_criterion_option
    stdout, _stderr, status = invoke("check", fixture("pairwise.rb"), "--criterion", PAIRWISE, "--format", "json")

    assert_equal 2, status.exitstatus
    report = JSON.parse(stdout)
    assert_equal "unsupported_option", report.fetch("errors").first.fetch("code")
  end

  def test_pairwise_cli_requires_a_group_for_each_target
    stdout, stderr, status = invoke("plan", fixture("multiple_inputs.rb"), "--criterion", PAIRWISE, "--format", "json")

    assert_equal 2, status.exitstatus, stderr
    report = JSON.parse(stdout)
    assert_equal "combinations_required", report.fetch("errors").first.fetch("code")
    assert_equal PAIRWISE, report.fetch("criterion")
  end

  def test_cli_rejects_unknown_criterion_and_keeps_the_requested_name
    stdout, stderr, status = invoke("plan", fixture("pairwise.rb"), "--criterion", "pairwise-future-v2",
                                    "--format", "json")

    assert_equal 2, status.exitstatus, stderr
    report = JSON.parse(stdout)
    assert_equal "pairwise-future-v2", report.fetch("criterion")
    assert_equal "unknown_criterion", report.fetch("errors").first.fetch("code")
  end

  def test_minitest_pairwise_preparation_failure_keeps_requested_criterion_and_test_result
    Dir.mktmpdir("specproof-pairwise-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      script = minitest_script(criterion: PAIRWISE)
      stdout, stderr, status = run_minitest(script, directory, fixture("multiple_inputs.rb"), report_path)

      refute status.success?, "preparation should fail while the test still runs: #{stdout}\n#{stderr}"
      assert File.file?(report_path), "Minitest did not write a report: #{stdout}\n#{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_equal PAIRWISE, report.fetch("criterion")
      assert_equal false, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
      assert_equal "combinations_required", report.fetch("errors").first.fetch("code")
    end
  end

  def test_runtime_missing_string_summary_quotes_values
    Dir.mktmpdir("specproof-pairwise-summary") do |directory|
      spec_path = File.join(directory, "strings_spec.rb")
      report_path = File.join(directory, "coverage.json")
      File.write(spec_path, <<~SPEC)
        SpecProof.define "StringPair#call" do
          input :left, values: ["alpha", "beta"]
          input :right, values: ["x", "y"]
          input :context, values: [:first, :second]
          combinations :left, :right, all_allowed: true
        end
      SPEC
      script = minitest_script(criterion: PAIRWISE, body: 'StringPair.new.call("alpha", "x", :first)')
      stdout, stderr, status = run_minitest(script, directory, spec_path, report_path)

      assert status.success?, "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      assert_includes stdout, "criterion: #{PAIRWISE}"
      assert_includes stdout, "group: StringPair#call(left, right)"
      refute_includes stdout, "group: StringPair#call(left, right, context)"
      assert_includes stdout, 'left="beta"'
      report = JSON.parse(File.read(report_path))
      assert_equal PAIRWISE, report.fetch("criterion")
      assert_equal true, report.fetch("tests_passed")
      assert_equal %w[left right], report.dig("scope", "input_scope", 0, "combination_group", "inputs")
      assert(report.fetch("missing").all? do |row|
        row.fetch("inputs").values.any? { |value| value.fetch("kind") == "string" }
      end)
    end
  end

  def test_minitest_strict_pairwise_missing_fails_without_changing_test_result
    Dir.mktmpdir("specproof-pairwise-strict") do |directory|
      report_path = File.join(directory, "coverage.json")
      script = minitest_script(criterion: PAIRWISE, fail_on_missing: true)
      stdout, stderr, status = run_minitest(script, directory, fixture("pairwise.rb"), report_path)

      refute status.success?, "strict missing pairs should fail: #{stdout}\n#{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal true, report.fetch("integrity")
      assert_equal 9, report.fetch("missing_count")
    end
  end

  def test_minitest_failing_assertion_is_preserved_after_complete_pairwise_coverage
    Dir.mktmpdir("specproof-pairwise-failing-test") do |directory|
      report_path = File.join(directory, "coverage.json")
      body = <<~BODY
        [[false, false, false], [false, true, true], [true, false, true], [true, true, false]].each do |values|
          Pairwise.new.call(*values)
        end
      BODY
      script = minitest_script(criterion: PAIRWISE, body: body, fail_test: true)
      stdout, stderr, status = run_minitest(script, directory, fixture("pairwise.rb"), report_path)

      refute status.success?, "the test assertion should still fail: #{stdout}\n#{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_equal false, report.fetch("tests_passed")
      assert_equal true, report.fetch("integrity")
      assert_equal "completed", report.fetch("completion")
      assert_equal 0, report.fetch("missing_count")
      assert_equal 12, report.fetch("exercised_count")
    end
  end

  def test_minitest_joint_forbidden_call_is_outside_without_failing_the_test
    Dir.mktmpdir("specproof-pairwise-forbidden") do |directory|
      report_path = File.join(directory, "coverage.json")
      script = minitest_script(criterion: PAIRWISE, body: "ConstrainedPairwise.new.call(true, false)")
      stdout, stderr, status = run_minitest(script, directory, fixture("pairwise_constrained.rb"), report_path)

      assert status.success?, "the negative input should remain a passing test: #{stdout}\n#{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal true, report.fetch("integrity")
      assert_equal 0, report.fetch("exercised_count")
      assert_equal 3, report.fetch("missing_count")
      assert_equal 1, report.fetch("outside_combinations").fetch("ConstrainedPairwise#call").fetch("count")
    end
  end

  private

  def pair_values(row)
    row.fetch(:inputs).values.map { |item| item.fetch(:value) }
  end

  def load_forbidden_triple(directory)
    path = File.join(directory, "forbidden_triple.rb")
    File.write(path, <<~SPEC)
      SpecProof.define "ForbiddenTriple#call" do
        input :a, values: [false, true]
        input :b, values: [false, true]
        input :c, values: [false, true]
        combinations :a, :b, :c do
          forbid a: true, b: false, c: false
        end
      end
    SPEC
    SpecProof.load([path])
  end

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def invoke(*)
    Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "-Ilib", "exe/specproof", *,
                   chdir: File.expand_path("..", __dir__))
  end

  def minitest_script(criterion:, body: "Pairwise.new.call(false, false, false)", fail_on_missing: false,
                      fail_test: false)
    <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"
      class Pairwise
        def call(a, b, c)
          [a, b, c]
        end
      end
      class StringPair
        def call(left, right, context)
          [left, right, context]
        end
      end
      class ConstrainedPairwise
        def call(a, b)
          [a, b]
        end
      end
      class PairwiseWorkflowMinitest < Minitest::Test
        def test_observation
          #{body}
          assert true
          assert false if #{fail_test}
        end
      end
      require "specproof/minitest"
      SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], criterion: #{criterion.inspect},
                                   output: ENV.fetch("REPORT_PATH"), fail_on_missing: #{fail_on_missing})
    RUBY
  end

  def run_minitest(script, directory, spec_path, report_path)
    env = {
      "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil,
      "MT_NO_PLUGINS" => "1", "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
      "SPEC_PATH" => spec_path,
      "REPORT_PATH" => report_path
    }
    Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)
  end
end
