# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class OptionalMinitestIntegrationTest < Minitest::Test
  def test_omitted_and_explicit_nil_share_the_offline_plan_obligation
    Dir.mktmpdir("specproof-optional-nil") do |directory|
      specification_path = write_specification(directory, <<~RUBY)
        SpecProof.define "OptionalPolicy#enabled?" do
          input :flag, values: [nil, true]
        end
      RUBY
      plan = offline_plan(specification_path)
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_fixture(
        directory,
        specification_path: specification_path,
        report_path: report_path,
        test_body: <<~RUBY,
          assert_nil OptionalPolicy.new.enabled?
          assert_nil OptionalPolicy.new.enabled?(flag: nil)
        RUBY
        method_body: "def enabled?(flag: nil) = flag"
      )

      assert status.success?, stderr + stdout + File.read(report_path)
      report = JSON.parse(File.read(report_path))
      assert_equal "effective_bound_values", report.dig("scope", "input_semantics")
      assert_equal "not_observed", report.dig("scope", "argument_presence")
      assert_equal plan.fetch("contract_digest"), report.fetch("contract_digest")
      assert_equal plan.fetch("criterion"), report.fetch("criterion")
      assert_equal plan.fetch("obligations").map { |row| row.fetch("id") }.sort,
                   report.fetch("obligations").map { |row| row.fetch("id") }.sort

      nil_obligation = report.fetch("obligations").find do |row|
        row.fetch("input") == "flag" && row.dig("value", "kind") == "nil"
      end
      assert_equal 2, nil_obligation.fetch("hits")
      assert_equal "exercised", nil_obligation.fetch("status")
      assert_equal 1, report.fetch("exercised_count")
      assert_equal true, report.fetch("integrity")
      assert_includes stdout, "2 assertions"
    end
  end

  def test_out_of_domain_optional_value_invalidates_the_complete_input_tuple
    Dir.mktmpdir("specproof-optional-tuple") do |directory|
      specification_path = write_specification(directory, <<~RUBY)
        SpecProof.define "OptionalPolicy#accept?" do
          input :age, range: 0..2
          input :mode, values: [:safe]
        end
      RUBY
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_fixture(
        directory,
        specification_path: specification_path,
        report_path: report_path,
        test_body: <<~RUBY,
          assert_equal [1, :unsafe], OptionalPolicy.new.accept?(age: 1, mode: :unsafe)
        RUBY
        method_body: "def accept?(age:, mode: :safe) = [age, mode]"
      )

      assert status.success?, stderr + stdout + File.read(report_path)
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal true, report.fetch("integrity")
      assert_equal 0, report.fetch("exercised_count")
      assert(report.fetch("obligations").all? do |row|
        row.fetch("hits").zero? && row.fetch("status") == "not_observed"
      end)
      assert_equal 1, report.dig("outside_domain", "OptionalPolicy#accept?", "count")
    end
  end

  private

  def write_specification(directory, contents)
    path = File.join(directory, "optional_spec.rb")
    File.write(path, contents)
    path
  end

  def offline_plan(specification_path)
    stdout, stderr, status = Open3.capture3(
      clean_environment.merge("RUBYLIB" => File.expand_path("../lib", __dir__)),
      RbConfig.ruby,
      File.expand_path("../exe/specproof", __dir__),
      "plan",
      specification_path,
      "--format",
      "json"
    )

    assert status.success?, stderr
    JSON.parse(stdout)
  end

  def run_fixture(directory, specification_path:, report_path:, test_body:, method_body:)
    script = <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"

      class OptionalPolicy
        #{method_body}
      end

      class OptionalCoverageTest < Minitest::Test
        def test_optional_values
          #{test_body.gsub("\n", "\n          ").strip}
        end
      end

      require "specproof/minitest"
      SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], output: ENV.fetch("REPORT_PATH"))
    RUBY
    Open3.capture3(
      clean_environment.merge(
        "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
        "SPEC_PATH" => specification_path,
        "REPORT_PATH" => report_path,
        "MT_NO_PLUGINS" => "1"
      ),
      RbConfig.ruby,
      "-e",
      script,
      chdir: directory
    )
  end

  def clean_environment
    {
      "RUBYOPT" => nil,
      "RUBYLIB" => nil,
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLER_SETUP" => nil,
      "BUNDLER_VERSION" => nil
    }
  end
end
