# frozen_string_literal: true

require "test_helper"
require "json"
require "tempfile"
require "tmpdir"
require "open3"
require "rbconfig"
require_relative "../lib/specproof/suggestion_report"

class PartitionSuggestionsTest < Minitest::Test
  CRITERION = "pairwise-partitions-v1"

  def setup
    @specifications = partition_specifications
    @obligations = SpecProof.plan(@specifications, criterion: CRITERION)
  end

  def test_suggests_native_representative_for_the_unobserved_category_pair
    coverage = SpecProof::Coverage.new(obligations: @obligations, specifications: @specifications)
    [{ age: 16, country: :ro }, { age: 30, country: :ro }, { age: 30, country: :de }].each do |inputs|
      assert coverage.observe(target: "AgePolicy#call", arguments: inputs)
    end

    result = SpecProof.suggest(@specifications, report: coverage_document(coverage, @specifications))

    assert_equal CRITERION, result.criterion
    assert_equal "greedy-partition-pairwise-v1", result.strategy
    assert_equal [{ age: 0, country: :de }], result.suggestions.map(&:inputs)
    assert_equal 1, result.missing_count
  end

  def test_suggestions_and_ids_are_stable_when_partition_declarations_are_reordered
    first = partition_specifications
    second = partition_specifications(reversed: true)

    first_result = suggest_after_observations(first)
    second_result = suggest_after_observations(second)

    assert_equal(first_result.suggestions.map { |item| [item.id, item.inputs, item.covers] },
                 second_result.suggestions.map { |item| [item.id, item.inputs, item.covers] })
  end

  def test_suggestion_report_uses_the_inferred_criterion_and_strategy
    result = suggest_after_observations(@specifications)
    document = JSON.parse(SpecProof::SuggestionReport.render(result, format: "json"))

    assert_equal CRITERION, document.fetch("criterion")
    assert_equal "greedy-partition-pairwise-v1", document.fetch("strategy")
    assert_equal({ "kind" => "integer", "value" => "0" }, document.dig("suggestions", 0, "inputs", "age"))
  end

  def test_one_suggestion_covers_multiple_missing_pairs_across_three_inputs
    specifications = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#matrix" do
        input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :country, values: [:ro, :de]
        input :platform, values: [:web, :native]
        combinations :age, :country, :platform, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: CRITERION)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    result = SpecProof.suggest(specifications, report: coverage_document(coverage, specifications))

    assert_operator result.suggestions.first.covers.length, :>, 1
    assert_equal obligations.map(&:id).sort, result.suggestions.flat_map(&:covers).sort
  end

  def test_large_integer_width_does_not_increase_partition_assignment_count
    specifications = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#huge" do
        input :age, range: 0..(10**100), allow_gaps: false, allow_overlaps: false do
          partition :minor, range: 0...(10**50)
          partition :adult, range: (10**50)..(10**100)
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    obligations = SpecProof.plan(specifications, criterion: CRITERION)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)

    result = SpecProof.suggest(specifications, report: coverage_document(coverage, specifications))

    assert_equal 4, obligations.length
    assert_equal 4, result.suggestions.length
    assert_equal [0, 10**50], result.suggestions.map { |item| item.inputs.fetch(:age) }.uniq.sort
  end

  def test_category_count_limit_is_checked_before_partition_enumeration
    source = SpecProof::Source.new(path: "many-partitions.rb", line: 1)
    age = SpecProof::Input.new(
      name: :age, domain: SpecProof::IntegerDomain.new(lower: 0, upper: 10_000),
      partitions: 10_001.times.map do |number|
        SpecProof::Partition.new(name: "p#{number}",
                                 domain: SpecProof::IntegerDomain.new(lower: number, upper: number), source: source)
      end,
      exhaustive: true, disjoint: true, source: source
    )
    country = SpecProof::Input.new(name: :country, domain: SpecProof::FiniteDomain.new(values: [:ro]),
                                   partitions: [], exhaustive: false, disjoint: false, source: source)
    group = SpecProof::CombinationGroup.new(inputs: %i[age country], forbidden: [], source: source)
    specifications = [SpecProof::Specification.new(target: "AgePolicy#too_many",
                                                   inputs: { age: age, country: country }, source: source,
                                                   combination_group: group)]

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.suggest(specifications, report: { "criterion" => CRITERION })
    end

    assert_equal "combination_limit_exceeded", error.code
  end

  def test_complete_pair_coverage_returns_no_suggestions_and_preserves_failed_test_status
    coverage = SpecProof::Coverage.new(obligations: @obligations, specifications: @specifications)
    [{ age: 16, country: :ro }, { age: 16, country: :de },
     { age: 30, country: :ro }, { age: 30, country: :de }].each do |inputs|
      coverage.observe(target: "AgePolicy#call", arguments: inputs)
    end

    result = SpecProof.suggest(@specifications,
                               report: coverage_document(coverage, @specifications, tests_passed: false))

    assert_empty result.suggestions
    assert_equal false, result.source_tests_passed
  end

  def test_missing_partition_policy_error_uses_readable_option_names
    specifications = load_text(<<~RUBY, allow_exclusion_only: true)
      SpecProof.define "Example#missing_policy" do
        input :age, range: 0..20 do
          partition :all, range: 0..20
        end
        input :country, values: [:ro]
        combinations :age, :country, all_allowed: true
      end
    RUBY

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.suggest(specifications, report: { "criterion" => CRITERION })
    end

    assert_equal "partition_policy_required", error.code
    assert_includes error.message, "allow_gaps: false"
    assert_includes error.message, "allow_overlaps: false"
  end

  def test_unknown_or_incomplete_source_evidence_is_rejected
    coverage = SpecProof::Coverage.new(obligations: @obligations, specifications: @specifications)
    report = coverage_document(coverage, @specifications)

    unknown = report.merge("unknown_count" => 1)
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.suggest(@specifications, report: unknown)
    end
    assert_equal "incomplete_coverage_report", error.code

    incomplete = report.merge("completion" => "incomplete")
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof.suggest(@specifications, report: incomplete)
    end
    assert_equal "incomplete_coverage_report", error.code
  end

  def test_cli_suggest_reads_partition_coverage_and_emits_partition_strategy
    Dir.mktmpdir("specproof-partition-cli") do |directory|
      spec_path = File.join(directory, "age.rb")
      report_path = File.join(directory, "coverage.json")
      File.write(spec_path, <<~RUBY)
        SpecProof.define "AgePolicy#call" do
          input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
            partition :minor, range: 0...18
            partition :adult, range: 18..120
          end
          input :country, values: [:ro, :de]
          combinations :age, :country, all_allowed: true
        end
      RUBY
      File.write(report_path, JSON.generate(coverage_document_from(@specifications)))

      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-Ilib", "exe/specproof", "suggest", spec_path,
                                              "--report", report_path, "--format", "json",
                                              chdir: File.expand_path("..", __dir__))

      assert status.success?, stderr
      document = JSON.parse(stdout)
      assert_equal CRITERION, document.fetch("criterion")
      assert_equal "greedy-partition-pairwise-v1", document.fetch("strategy")
      assert_equal 1, document.fetch("suggestion_count")
    end
  end

  def test_cli_suggest_semantic_findings_keep_the_partition_criterion
    Dir.mktmpdir("specproof-partition-cli-invalid") do |directory|
      spec_path = File.join(directory, "age.rb")
      report_path = File.join(directory, "coverage.json")
      File.write(spec_path, <<~RUBY)
        SpecProof.define "AgePolicy#call" do
          input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
            partition :minor, range: 0...18
            partition :adult, range: 19..120
          end
          input :country, values: [:ro, :de]
          combinations :age, :country, all_allowed: true
        end
      RUBY
      File.write(report_path, JSON.generate("criterion" => CRITERION))

      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-Ilib", "exe/specproof", "suggest", spec_path,
                                              "--report", report_path, "--format", "json",
                                              chdir: File.expand_path("..", __dir__))

      assert_equal 1, status.exitstatus, stderr
      document = JSON.parse(stdout)
      assert_equal CRITERION, document.fetch("criterion")
      assert_equal "greedy-partition-pairwise-v1", document.fetch("strategy")
      assert_equal "partition_gap", document.fetch("findings").first.fetch("code")
    end
  end

  private

  def load_text(text, allow_exclusion_only: false)
    Tempfile.create(["partition-suggestions", ".rb"]) do |file|
      file.write(text)
      file.flush
      SpecProof::Loader.load([file.path], allow_exclusion_only: allow_exclusion_only)
    end
  end

  def partition_specifications(reversed: false)
    partitions = if reversed
                   "partition :adult, range: 18..120\npartition :minor, range: 0...18"
                 else
                   "partition :minor, range: 0...18\npartition :adult, range: 18..120"
                 end
    load_text(<<~RUBY)
      SpecProof.define "AgePolicy#call" do
        input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
          #{partitions}
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY
  end

  def suggest_after_observations(specifications)
    obligations = SpecProof.plan(specifications, criterion: CRITERION)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    [{ age: 16, country: :ro }, { age: 30, country: :ro }, { age: 30, country: :de }].each do |inputs|
      coverage.observe(target: "AgePolicy#call", arguments: inputs)
    end
    SpecProof.suggest(specifications, report: coverage_document(coverage, specifications))
  end

  def coverage_document(coverage, specifications, tests_passed: true)
    runtime_scope = {
      ruby_engine: RUBY_ENGINE, pid: Process.pid, thread: Thread.current.object_id,
      window: "minitest_run", method_identity: "direct_owner_definition",
      input_semantics: "effective_bound_values", argument_presence: "not_observed",
      targets: specifications.map(&:target).sort, declaration_sources: { specifications: [], rbs: [], targets: [] },
      arguments: [], filter: nil, exclude: nil
    }
    projection = coverage.to_report
    document = SpecProof::Report.envelope(kind: "coverage").merge(
      contract_digest: SpecProof::Report.digest(specifications), criterion: CRITERION,
      run_id: "partition-test-run", scope: runtime_scope.merge(SpecProof::Report.input_scope(specifications)),
      completion: "completed", integrity: true, tests_passed: tests_passed,
      evidence_mode: "obligation_hits", replay: false
    ).merge(projection.except(:status, :completeness))
    JSON.parse(JSON.generate(document))
  end

  def coverage_document_from(specifications)
    obligations = SpecProof.plan(specifications, criterion: CRITERION)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    [{ age: 16, country: :ro }, { age: 30, country: :ro }, { age: 30, country: :de }].each do |inputs|
      coverage.observe(target: "AgePolicy#call", arguments: inputs)
    end
    coverage_document(coverage, specifications)
  end
end
