# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class PartitionPairwiseWorkflowTest < Minitest::Test
  CRITERION = "pairwise-partitions-v1"

  def test_cli_plan_reports_category_pairs
    Dir.mktmpdir("specproof-partition-plan") do |directory|
      specification = write_specification(directory)
      stdout, stderr, status = invoke("plan", specification, "--criterion", CRITERION, "--format", "json")

      assert status.success?, "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      report = JSON.parse(stdout)
      assert_equal CRITERION, report.fetch("criterion")
      assert_equal 4, report.fetch("obligations").length
      categories = report.fetch("obligations").map { |row| row.fetch("inputs").fetch("age") }
      assert_equal [
        { "kind" => "partition", "name" => "minor", "lower" => "0", "upper" => "17" },
        { "kind" => "partition", "name" => "adult", "lower" => "18", "upper" => "120" }
      ], categories.uniq

      text, text_stderr, text_status = invoke("plan", specification, "--criterion", CRITERION)
      assert text_status.success?, "stdout:\n#{text}\nstderr:\n#{text_stderr}"
      assert_includes text, "minor[0..17]"
      assert_includes text, "adult[18..120]"
    end
  end

  def test_coverage_matches_partition_pairs_from_one_valid_native_call
    Dir.mktmpdir("specproof-partition-coverage") do |directory|
      specifications = SpecProof.load([write_specification(directory)])
      obligations = SpecProof.plan(specifications, criterion: CRITERION)
      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

      coverage.observe(target: "Age#check", arguments: { age: 16, country: :ro, trace: false })
      coverage.observe(target: "Age#check", arguments: { age: 30, country: :ro, trace: true })
      coverage.observe(target: "Age#check", arguments: { age: 30, country: :de, trace: false })

      report = coverage.to_report
      assert_equal 3, report.fetch(:exercised_count)
      assert_equal 1, report.fetch(:missing_count)
      missing = report.fetch(:missing).fetch(0)
      assert_equal "minor", missing.fetch(:inputs).fetch("age").fetch(:name)
      assert_equal "symbol", missing.fetch(:inputs).fetch("country").fetch(:kind)
      assert_equal "de", missing.fetch(:inputs).fetch("country").fetch(:value)
    end
  end

  def test_out_of_domain_tuple_does_not_hit_any_partition_pair
    Dir.mktmpdir("specproof-partition-outside") do |directory|
      specifications = SpecProof.load([write_specification(directory)])
      obligations = SpecProof.plan(specifications, criterion: CRITERION)
      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

      refute coverage.observe(target: "Age#check", arguments: { age: 121, country: :ro, trace: false })
      report = coverage.to_report
      assert_equal obligations.length, report.fetch(:missing_count)
      assert_equal 1, report.fetch(:outside_domain).fetch("Age#check").fetch(:count)
    end
  end

  def test_forbidden_partition_tuple_is_outside_combinations_and_hits_no_pair
    Dir.mktmpdir("specproof-partition-forbidden") do |directory|
      path = File.join(directory, "registration.rb")
      File.write(path, <<~SPEC)
        SpecProof.define "Registration#submit" do
          input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
            partition :minor, range: 0...18
            partition :adult, range: 18..120
          end
          input :account, values: [:personal, :business]
          input :country, values: [:ro, :de]
          combinations :age, :account, :country do
            forbid age: in_partition(:minor), account: :business
          end
        end
      SPEC
      specifications = SpecProof.load([path])
      obligations = SpecProof.plan(specifications, criterion: CRITERION)
      coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

      refute coverage.observe(target: "Registration#submit",
                              arguments: { age: 16, account: :business, country: :ro })

      report = coverage.to_report
      assert_equal 0, report.fetch(:exercised_count)
      assert_equal obligations.length, report.fetch(:missing_count)
      assert_equal 1, report.fetch(:outside_combinations).fetch("Registration#submit").fetch(:count)

      scalar_obligations = SpecProof.plan(specifications)
      scalar_ids = scalar_obligations.map(&:id)
      combined = SpecProof::Coverage.new(obligations: obligations + scalar_obligations,
                                         specifications: specifications)
      refute combined.observe(target: "Registration#submit",
                              arguments: { age: 16, account: :business, country: :ro })
      refute(combined.to_report.fetch(:exercised).any? { |item| scalar_ids.include?(item.fetch(:id)) })
    end
  end

  def test_scalar_obligations_in_the_same_specification_remain_exact
    Dir.mktmpdir("specproof-partition-scalar") do |directory|
      specifications = SpecProof.load([write_specification(directory)])
      pair_obligations = SpecProof.plan(specifications, criterion: CRITERION)
      scalar_obligations = SpecProof.plan(specifications)
      scalar_obligation = scalar_obligations.find { |item| item.input == :age && item.value == 18 }
      refute_nil scalar_obligation
      coverage = SpecProof::Coverage.new(obligations: pair_obligations + scalar_obligations,
                                         specifications: specifications)

      coverage.observe(target: "Age#check", arguments: { age: 19, country: :ro, trace: false })
      exercised = coverage.to_report.fetch(:exercised)
      pair_count = exercised.count { |item| item.fetch(:inputs, {}).key?("age") }
      scalar_hit = exercised.any? { |item| item[:input] == "age" && item[:value][:value] == "18" }
      assert_equal 1, pair_count
      refute scalar_hit

      coverage.observe(target: "Age#check", arguments: { age: 18, country: :ro, trace: true })
      assert_includes coverage.to_report.fetch(:exercised).map { |item| item[:id] }, scalar_obligation.id
    end
  end

  def test_minitest_report_and_summary_name_missing_category_pairs
    Dir.mktmpdir("specproof-partition-minitest") do |directory|
      specification = write_specification(directory)
      report_path = File.join(directory, "coverage.json")
      script = minitest_script
      stdout, stderr, status = run_minitest(script, directory, specification, report_path)

      assert status.success?, "stdout:\n#{stdout}\nstderr:\n#{stderr}"
      report = JSON.parse(File.read(report_path))
      assert_equal CRITERION, report.fetch("criterion")
      assert_equal 4, report.fetch("obligation_count")
      assert_equal 3, report.fetch("exercised_count")
      assert_equal 1, report.fetch("missing_count")
      missing_age = report.fetch("missing").fetch(0).fetch("inputs").fetch("age")
      assert_equal({ "kind" => "partition", "name" => "minor", "lower" => "0", "upper" => "17" },
                   missing_age)
      assert_includes stdout, "pairwise-partitions-v1"
      assert_includes stdout, "minor[0..17]"
      assert_includes stdout, "3/4 pair obligations exercised"
      refute_includes stdout, "boundary"
    end
  end

  private

  def write_specification(directory)
    path = File.join(directory, "age_spec.rb")
    File.write(path, <<~SPEC)
      SpecProof.define "Age#check" do
        input :age, range: 0..120, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :country, values: [:ro, :de]
        input :trace, values: [false, true]
        combinations :age, :country, all_allowed: true
      end
    SPEC
    path
  end

  def invoke(*)
    Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "-Ilib", "exe/specproof", *,
                   chdir: File.expand_path("..", __dir__))
  end

  def minitest_script
    <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"
      class Age
        def check(age, country, trace)
          [age, country, trace]
        end
      end
      class PartitionWorkflowMinitest < Minitest::Test
        def test_observations
          Age.new.check(16, :ro, false)
          Age.new.check(30, :ro, true)
          Age.new.check(30, :de, false)
          assert true
        end
      end
      require "specproof/minitest"
      SpecProof::Minitest.install!(specifications: [ENV.fetch("SPEC_PATH")],
                                   criterion: #{CRITERION.inspect}, output: ENV.fetch("REPORT_PATH"))
    RUBY
  end

  def run_minitest(script, directory, spec_path, report_path)
    env = {
      "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil,
      "MT_NO_PLUGINS" => "1", "SPECPROOF_LIB" => File.expand_path("../lib", __dir__),
      "SPEC_PATH" => spec_path, "REPORT_PATH" => report_path
    }
    Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)
  end
end
