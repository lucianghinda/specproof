# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class RBSStringLiteralsWorkflowTest < Minitest::Test
  TARGET = "Delivery#build"

  def test_rbs_literal_inputs_flow_through_pairwise_coverage_and_suggestions
    Dir.mktmpdir("specproof-rbs-string-literals-", "/private/tmp") do |directory|
      dsl_path = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "#{TARGET}" do
          combinations :country, :expedited, all_allowed: true
        end
      RUBY
      rbs_path = write(directory, "delivery.rbs", <<~RBS)
        class Delivery
          def build: (country: ('ro' | 'de'), expedited: bool) -> untyped
        end
      RBS
      # Independent implementation fixture requirement: build returns [country, expedited] unchanged.
      implementation_path = write(directory, "delivery.rb", <<~RUBY)
        class Delivery
          def build(country:, expedited:)
            [country, expedited]
          end
        end
      RUBY
      original_inputs = [dsl_path, rbs_path, implementation_path].to_h { |path| [path, File.binread(path)] }

      output = File.join(directory, "coverage.json")
      stdout, stderr, status = run_minitest(
        directory, dsl_path:, rbs_path:, implementation_path:, output:
      )
      assert status.success?, "#{stdout}\n#{stderr}"

      report = JSON.parse(File.read(output))
      assert_coverage(report)
      missing = report.fetch("obligations").find { |obligation| obligation.fetch("status") == "not_observed" }
      assert_equal({ "country" => { "kind" => "string", "value" => "de" },
                     "expedited" => { "kind" => "boolean", "value" => true } }, missing.fetch("inputs"))
      coverage_before_suggest = File.binread(output)

      suggest_stdout, suggest_stderr, suggest_status = invoke(
        "suggest", dsl_path, "--rbs", rbs_path, "--target", TARGET, "--report", output, "--format", "json"
      )
      assert_suggestion(suggest_stdout, suggest_stderr, suggest_status, rbs_path, missing.fetch("id"))
      assert_equal coverage_before_suggest, File.binread(output)

      current_inputs = original_inputs.keys.to_h { |path| [path, File.binread(path)] }
      assert_equal original_inputs, current_inputs
    end
  end

  def test_unsupported_rbs_string_type_fails_suggest_atomically
    Dir.mktmpdir("specproof-rbs-string-literals-unsupported-", "/private/tmp") do |directory|
      dsl_path = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "#{TARGET}" do
          combinations :country, :expedited, all_allowed: true
        end
      RUBY
      rbs_path = write(directory, "unsupported.rbs", <<~RBS)
        class Delivery
          def build: (country: String, expedited: bool) -> bool
        end
      RBS
      report_path = write(directory, "coverage.json", JSON.generate("completion" => "complete", "obligations" => []))

      stdout, stderr, status = invoke(
        "suggest", dsl_path, "--rbs", rbs_path, "--target", TARGET, "--report", report_path, "--format", "json"
      )

      assert_equal 2, status.exitstatus, "#{stdout}\n#{stderr}"
      assert_empty stderr
      payload = JSON.parse(stdout)
      assert_equal "unsupported_rbs_type", payload.fetch("errors").first.fetch("code")
      refute payload.key?("suggestions")
      assert_equal({ "completion" => "complete", "obligations" => [] }, JSON.parse(File.read(report_path)))
    end
  end

  private

  def write(directory, name, contents)
    path = File.join(directory, name)
    File.write(path, contents)
    path
  end

  def assert_coverage(report)
    assert_equal "completed", report.fetch("completion")
    assert_equal true, report.fetch("tests_passed")
    assert_equal [TARGET], report.dig("scope", "targets")
    obligations = report.fetch("obligations")
    statuses = obligations.map { |obligation| obligation.fetch("status") }.tally
    assert_equal 4, obligations.length
    assert_equal 3, statuses.fetch("exercised", 0)
    assert_equal 1, statuses.fetch("not_observed", 0)
    assert(obligations.all? do |obligation|
      obligation.fetch("sources").any? { |source| source.fetch("kind") == "rbs" }
    end)
  end

  def assert_suggestion(stdout, stderr, status, rbs_path, missing_id)
    assert status.success?, "#{stdout}\n#{stderr}"
    assert_empty stderr
    suggestions = JSON.parse(stdout).fetch("suggestions")
    assert_equal 1, suggestions.length
    suggestion = suggestions.first
    assert_equal TARGET, suggestion.fetch("target")
    assert_equal({ "country" => { "kind" => "string", "value" => "de" },
                   "expedited" => { "kind" => "boolean", "value" => true } }, suggestion.fetch("inputs"))
    assert_includes suggestion.fetch("sources").map { |source| source.fetch("kind") }, "rbs"
    assert_includes suggestion.fetch("sources").map { |source| source.fetch("path") }, File.realpath(rbs_path)
    assert_equal [missing_id], suggestion.fetch("covers")
  end

  def invoke(*)
    Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "-Ilib", "exe/specproof", *,
                   chdir: File.expand_path("../..", __dir__))
  end

  def run_minitest(directory, dsl_path:, rbs_path:, implementation_path:, output:)
    script = <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"
      require ENV.fetch("IMPLEMENTATION_PATH")
      class LiteralInputsWorkflowTest < Minitest::Test
        def test_three_real_calls
          delivery = Delivery.new
          assert_equal ["ro", false], delivery.build(country: "ro", expedited: false)
          assert_equal ["de", false], delivery.build(country: "de", expedited: false)
          assert_equal ["ro", true], delivery.build(country: "ro", expedited: true)
        end
      end
      require "specproof/minitest"
      SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], rbs: [ENV.fetch("RBS_PATH")],
                                   targets: [#{TARGET.inspect}], criterion: "pairwise-finite-v1",
                                   output: ENV.fetch("REPORT_PATH"))
    RUBY
    env = {
      "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil,
      "MT_NO_PLUGINS" => "1", "SPECPROOF_LIB" => File.expand_path("../../lib", __dir__),
      "IMPLEMENTATION_PATH" => implementation_path, "SPEC_PATH" => dsl_path, "RBS_PATH" => rbs_path,
      "REPORT_PATH" => output
    }
    Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)
  end
end
