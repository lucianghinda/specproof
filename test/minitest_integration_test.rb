# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

class MinitestIntegrationTest < Minitest::Test
  def test_serial_run_writes_new_coverage_report_and_matching_summary
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      File.write(report_path, '{"completion":"completed","run_id":"stale"}')
      stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "all")

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      refute_equal "stale", report.fetch("run_id")
      assert_equal "coverage", report.fetch("kind")
      assert_equal "completed", report.fetch("completion")
      assert_equal true, report.fetch("integrity")
      assert_equal "obligation_hits", report.fetch("evidence_mode")
      assert_equal false, report.fetch("replay")
      assert_equal RUBY_ENGINE, report.dig("scope", "ruby_engine")
      assert_equal "minitest_run", report.dig("scope", "window")
      assert_equal "direct_owner_definition", report.dig("scope", "method_identity")
      assert_equal ["AgePolicy#adult?"], report.dig("scope", "targets")
      assert_equal([0, 1, 17, 18, 119, 120], report.fetch("obligations").map { |row| row.dig("value", "value").to_i })
      assert(report.fetch("obligations").all? { |row| row.fetch("status") == "exercised" && row.fetch("hits") == 1 })
      summary_id = stdout[/SpecProof coverage run ([0-9a-f-]+)/, 1]
      assert_equal report.fetch("run_id"), summary_id
      assert_includes stdout, "6/6 obligations exercised"
    end
  end

  def test_interrupted_run_replaces_stale_report_with_a_running_marker
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      ready_path = File.join(directory, "ready")
      File.write(report_path, '{"completion":"completed","run_id":"stale"}')
      script = <<~RUBY
        gem "minitest", "~> 5.26.2"
        $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
        require "specproof"
        require "minitest/autorun"

        class AgePolicy
          def adult?(age:)
            age >= 18
          end
        end

        class HangingCoverageTest < Minitest::Test
          def test_hangs_after_a_target_call
            AgePolicy.new.adult?(age: 0)
            File.write(ENV.fetch("READY_PATH"), "ready")
            sleep 30
          end
        end

        require "specproof/minitest"
        SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")], output: ENV.fetch("REPORT_PATH"))
      RUBY
      env = {
        "RUBYOPT" => nil,
        "RUBYLIB" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_LOCKFILE" => nil,
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLER_SETUP" => nil,
        "BUNDLER_VERSION" => nil,
        "MT_NO_PLUGINS" => "1",
        "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
        "SPEC_PATH" => File.expand_path("fixtures/minitest/age_spec.rb", __dir__),
        "REPORT_PATH" => report_path,
        "READY_PATH" => ready_path
      }
      stdin, stdout, stderr, waiter = Open3.popen3(env, RbConfig.ruby, "-e", script)
      stdin.close
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 8
      until File.exist?(ready_path) || waiter.join(0.02) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        Thread.pass
      end

      assert File.exist?(ready_path), "child process did not reach its test method"
      running = JSON.parse(File.read(report_path))
      assert_equal "running", running.fetch("completion")
      refute_equal "stale", running.fetch("run_id")
      Process.kill("KILL", waiter.pid)
      waiter.value
      stdout.read
      stderr.read
    ensure
      Process.kill("KILL", waiter.pid) if waiter&.alive?
      [stdin, stdout, stderr].compact.each { |io| io.close unless io.closed? }
    end
  end

  def test_filter_scope_and_zero_observation_do_not_claim_a_percentage
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "one",
                                                      args: ["--name", "/test_one/"])

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal "/test_one/", report.dig("scope", "filter")
      assert_equal 1, report.fetch("exercised_count")
      assert_equal 16.67, report.fetch("completion_percent")
      assert_equal 5, report.fetch("missing_count")
      assert_equal %w[exercised not_observed], report.fetch("obligations").map { |row|
        row.fetch("status")
      }.uniq.sort
      assert_equal "completed", report.fetch("completion")
      assert_includes stdout, "1/6 obligations exercised"
      assert_includes stdout, "AgePolicy#adult?/age=18"
    end

    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "skip")
      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_nil report.fetch("completion_percent")
      assert_equal 0, report.fetch("exercised_count")
      assert_equal 6, report.fetch("missing_count")
      assert_equal 6, report.fetch("not_observed_count")
      assert_includes stdout, "AgePolicy#adult?/age=0"
    end
  end

  def test_out_of_domain_input_invalidates_the_whole_call_tuple
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "outside")

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal 0, report.fetch("exercised_count")
      assert_equal 1, report.fetch("outside_domain").fetch("AgePolicy#adult?").fetch("count")
      assert_equal "completed", report.fetch("completion")
    end
  end

  def test_exclusion_pattern_is_explicit_in_collection_scope
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "one",
                                                       args: ["--name", "/test_one/", "--exclude", "/test_one/"])
      refute status.success?, "Minitest rejects a filter with no matching tests: #{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_nil report.fetch("tests_passed")
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal "/test_one/", report.dig("scope", "exclude")
      assert_equal 0, report.fetch("exercised_count")
      assert_nil report.fetch("completion_percent")
    end
  end

  def test_child_thread_and_process_calls_stay_outside_the_reported_scope
    skip "fork is unavailable" unless Process.respond_to?(:fork)

    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "outside_scope")

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("integrity")
      assert_kind_of Integer, report.dig("scope", "pid")
      refute_equal Process.pid, report.dig("scope", "pid")
      assert_equal 0, report.fetch("exercised_count")
      assert_equal 6, report.fetch("not_observed_count")
      assert(report.fetch("obligations").all? { |row| row.fetch("status") == "not_observed" })
    end
  end

  def test_strict_missing_obligations_fails_run_without_masking_test_result
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "one", strict: true)

      refute status.success?
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal 5, report.fetch("missing_count")
    end
  end

  def test_duplicate_installation_is_a_configuration_error
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all",
                                                       install_twice: true)
      refute status.success?
      assert_includes stderr, "already installed"
    end
  end

  def test_collector_start_failure_runs_tests_and_marks_obligations_unknown
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "one", bad_target: true)

      refute status.success?
      assert_includes stdout, "1 runs, 1 assertions"
      report = JSON.parse(File.read(report_path))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal "undefined_target", report.fetch("errors").first.fetch("code")
      assert_equal ["unknown"], report.fetch("obligations").map { |row| row.fetch("status") }.uniq
    end
  end

  def test_actual_parallel_suite_is_rejected_but_tests_still_run
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "one", parallel: true)

      refute status.success?
      assert_includes stdout, "1 runs, 1 assertions"
      report = JSON.parse(File.read(report_path))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal "parallel_suite", report.fetch("errors").first.fetch("code")
    end
  end

  def test_collector_stop_issue_is_reported_and_preserves_observed_hits
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "one", stop_failure: true)

      refute status.success?
      report = JSON.parse(File.read(report_path))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal "collector_stop_failed", report.fetch("errors").last.fetch("code")
      assert_equal "exercised", report.fetch("obligations").find { |row|
        row.dig("value", "value") == "0"
      }.fetch("status")
      assert_equal 5, report.fetch("unknown_count")
    end
  end

  def test_target_constant_rebinding_preserves_hits_but_invalidates_collection
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "one", rebind_target: true)

      refute status.success?
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal "target_binding_changed", report.fetch("errors").last.fetch("code")
      assert_equal 1, report.fetch("exercised_count")
      assert_equal 5, report.fetch("unknown_count")
      assert_nil report.fetch("completion_percent")
    end
  end

  def test_unwritable_report_does_not_skip_tests_or_claim_analysis
    Dir.mktmpdir("specproof-minitest") do |directory|
      output_directory = File.join(directory, "coverage.json")
      Dir.mkdir(output_directory)
      stdout, stderr, status = run_fixture(directory, output: output_directory, scenario: "one")

      refute status.success?
      assert_includes stdout, "1 runs, 1 assertions"
      assert_includes stderr, "coverage report failed"
      assert File.directory?(output_directory)
      assert_equal [], Dir.children(output_directory)
    end
  end

  def test_original_runner_exception_survives_report_failure
    Dir.mktmpdir("specproof-minitest") do |directory|
      output_directory = File.join(directory, "coverage.json")
      Dir.mkdir(output_directory)
      _stdout, stderr, status = run_fixture(directory, output: output_directory, scenario: "one",
                                                       runner_exception: true)

      refute status.success?
      assert_includes stderr, "original runner exception"
      assert_includes stderr, "coverage report failed"
    end
  end

  def test_unsupported_minitest_runtime_version_is_rejected
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all",
                                                       runtime_version: "6.0.0")

      refute status.success?
      assert_includes stderr, "supports Minitest >= 5.26.2 and < 5.28.0"
      assert_includes stderr, "runtime 6.0.0"
    end
  end

  def test_mislabeled_minitest_package_and_runtime_mismatch_is_rejected
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all",
                                                       package_version: "5.27.0")

      refute status.success?
      assert_includes stderr, "loaded package 5.27.0, runtime 5.26.2"
    end
  end

  def test_minitest_5_26_2_is_supported
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all")

      assert status.success?, stderr
      assert_equal "completed", JSON.parse(File.read(File.join(directory, "coverage.json"))).fetch("completion")
    end
  end

  def test_package_and_runtime_minor_versions_must_match
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(
        directory,
        output: File.join(directory, "coverage.json"),
        scenario: "all",
        runtime_version: "5.27.0",
        package_version: "5.26.2"
      )

      refute status.success?
      assert_includes stderr, "loaded package 5.26.2, runtime 5.27.0"
    end
  end

  def test_minitest_5_26_1_is_unsupported
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all",
                                                       runtime_version: "5.26.1", package_version: "5.26.1")

      refute status.success?
      assert_includes stderr, "runtime 5.26.1"
    end
  end

  def test_minitest_5_28_is_unsupported
    Dir.mktmpdir("specproof-minitest") do |directory|
      _stdout, stderr, status = run_fixture(directory, output: File.join(directory, "coverage.json"), scenario: "all",
                                                       runtime_version: "5.28.0", package_version: "5.28.0")

      refute status.success?
      assert_includes stderr, "runtime 5.28.0"
    end
  end

  def test_optional_arguments_report_effective_values_without_argument_presence_claims
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "defaults", optional_target: true)

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal "effective_bound_values", report.dig("scope", "input_semantics")
      assert_equal "not_observed", report.dig("scope", "argument_presence")
      assert_equal 6, report.fetch("obligation_count")
      assert_equal 2, report.fetch("exercised_count")
      assert_equal 4, report.fetch("missing_count")
      assert_equal 2, report.fetch("obligations").find { |row| row.dig("value", "value") == "0" }.fetch("hits")
      assert_equal true, report.fetch("integrity")
      assert_includes stdout, "3 assertions"
    end
  end

  def test_raising_default_preserves_the_exception_and_does_not_supply_an_entry_hit
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "raising_default",
                                                       optional_target: true, default_kind: "raise")

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal 1, report.fetch("exercised_count")
      assert_equal 1, report.fetch("obligations").find { |row| row.dig("value", "value") == "0" }.fetch("hits")
      assert_equal true, report.fetch("tests_passed")
      assert_equal true, report.fetch("integrity")
      assert_empty report.fetch("errors")
    end
  end

  def test_primitive_default_outside_the_domain_remains_an_invalid_tuple
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, stderr, status = run_fixture(directory, output: report_path, scenario: "default_only",
                                                       optional_target: true, default_kind: "outside")

      assert status.success?, stderr
      report = JSON.parse(File.read(report_path))
      assert_equal 0, report.fetch("exercised_count")
      assert_equal 1, report.dig("outside_domain", "AgePolicy#adult?", "count")
      assert_equal true, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
    end
  end

  def test_non_primitive_default_keeps_analysis_incomplete_without_changing_test_result
    Dir.mktmpdir("specproof-minitest") do |directory|
      report_path = File.join(directory, "coverage.json")
      _stdout, _stderr, status = run_fixture(directory, output: report_path, scenario: "default_only",
                                                        optional_target: true, default_kind: "opaque")

      refute status.success?
      report = JSON.parse(File.read(report_path))
      assert_equal true, report.fetch("tests_passed")
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal 6, report.fetch("unknown_count")
      assert_equal "non_primitive_argument", report.fetch("errors").last.fetch("code")
    end
  end

  private

  def run_fixture(
    directory, output:, scenario:, args: [], strict: false, bad_target: false, install_twice: false,
    parallel: false, stop_failure: false, runner_exception: false, runtime_version: nil, package_version: nil,
    rebind_target: false, optional_target: false, default_kind: "scalar"
  )
    script = <<~'RUBY'
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"

      class AgePolicy
        if ENV.fetch("OPTIONAL_TARGET") == "1"
          def adult?(age: default_age)
            age.is_a?(Integer) && age >= 18
          end

          private

          def default_age
            case ENV.fetch("DEFAULT_KIND")
            when "raise" then raise "default failed"
            when "opaque" then Object.new
            when "outside" then -1
            else 0
            end
          end
        else
          def adult?(age:)
            age >= 18
          end
        end
      end

      class CoverageFixtureTest < Minitest::Test
        def test_defaults
          refute AgePolicy.new.adult?
          refute AgePolicy.new.adult?(age: 0)
          assert AgePolicy.new.adult?(age: 18)
        end

        def test_raising_default
          error = assert_raises(RuntimeError) { AgePolicy.new.adult? }
          assert_equal "default failed", error.message
          refute AgePolicy.new.adult?(age: 0)
        end

        def test_default_only
          refute AgePolicy.new.adult?
        end

        def self.test_order
          ENV["PARALLEL"] == "1" ? :parallel : :random
        end

        def test_one
          AgePolicy.new.adult?(age: 0)
          if ENV.fetch("REBIND_TARGET") == "1"
            Object.send(:remove_const, :AgePolicy)
            Object.const_set(:AgePolicy, Class.new)
          end
          assert true
        end

        def test_all
          [0, 1, 17, 18, 119, 120].each { |age| AgePolicy.new.adult?(age: age) }
          assert true
        end

        def test_outside
          AgePolicy.new.adult?(age: 121)
          assert true
        end

        def test_skipped
          skip "intentional zero-observation run"
        end

        def test_outside_scope
          Thread.new { AgePolicy.new.adult?(age: 0) }.join
          child = fork { AgePolicy.new.adult?(age: 1); exit! }
          Process.wait(child)
          assert true
        end
      end

      require "specproof/minitest"
      if ENV["RUNTIME_VERSION_OVERRIDE"]
        ::Minitest.send(:remove_const, :VERSION)
        ::Minitest.const_set(:VERSION, ENV.fetch("RUNTIME_VERSION_OVERRIDE"))
      end
      if ENV["PACKAGE_VERSION_OVERRIDE"]
        fake_spec = Struct.new(:version).new(Gem::Version.new(ENV.fetch("PACKAGE_VERSION_OVERRIDE")))
        Gem.loaded_specs["minitest"] = fake_spec
      end
      if ENV.fetch("RUNNER_EXCEPTION") == "1"
        ::Minitest.singleton_class.prepend(Module.new do
          def run(*_args, **_kwargs)
            raise "original runner exception"
          end
        end)
      end
      if ENV.fetch("STOP_FAILURE") == "1"
        SpecProof::Collector.prepend(Module.new do
          def stop
            super
            raise "forced stop failure"
          end
        end)
      end
      specification = ENV.fetch("BAD_TARGET") == "1" ? ENV.fetch("INVALID_SPEC_PATH") : ENV.fetch("SPEC_PATH")
      SpecProof::Minitest.install!(specifications: [specification], output: ENV.fetch("REPORT_PATH"), fail_on_missing: ENV.fetch("STRICT") == "1")
      SpecProof::Minitest.install!(specifications: [specification]) if ENV.fetch("INSTALL_TWICE") == "1"
      ARGV.replace(ENV.fetch("TEST_ARGS").split("\u001f").reject(&:empty?))
      if ARGV.empty?
        case ENV.fetch("SCENARIO")
        when "all" then ARGV.replace(["--name", "/test_all/"])
        when "one" then ARGV.replace(["--name", "/test_one/"])
        when "outside" then ARGV.replace(["--name", "/test_outside/"])
        when "skip" then ARGV.replace(["--name", "/test_skipped/"])
        when "outside_scope" then ARGV.replace(["--name", "/test_outside_scope/"])
        when "defaults" then ARGV.replace(["--name", "/test_defaults/"])
        when "raising_default" then ARGV.replace(["--name", "/test_raising_default/"])
        when "default_only" then ARGV.replace(["--name", "/test_default_only/"])
        end
      end
    RUBY
    env = {
      "RUBYOPT" => nil,
      "RUBYLIB" => nil,
      "BUNDLE_GEMFILE" => nil,
      "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLER_SETUP" => nil,
      "BUNDLER_VERSION" => nil,
      "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
      "SPEC_PATH" => File.expand_path("fixtures/minitest/age_spec.rb", __dir__),
      "INVALID_SPEC_PATH" => File.expand_path("fixtures/minitest/invalid_target_spec.rb", __dir__),
      "REPORT_PATH" => output,
      "SCENARIO" => scenario,
      "STRICT" => strict ? "1" : "0",
      "BAD_TARGET" => bad_target ? "1" : "0",
      "REBIND_TARGET" => rebind_target ? "1" : "0",
      "OPTIONAL_TARGET" => optional_target ? "1" : "0",
      "DEFAULT_KIND" => default_kind,
      "STOP_FAILURE" => stop_failure ? "1" : "0",
      "PARALLEL" => parallel ? "1" : "0",
      "INSTALL_TWICE" => install_twice ? "1" : "0",
      "RUNNER_EXCEPTION" => runner_exception ? "1" : "0",
      "RUNTIME_VERSION_OVERRIDE" => runtime_version,
      "PACKAGE_VERSION_OVERRIDE" => package_version,
      "TEST_ARGS" => args.join("\u001f"),
      "MT_NO_PLUGINS" => "1"
    }
    Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)
  end
end
