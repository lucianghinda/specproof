# frozen_string_literal: true

require "test_helper"
require "json"
require "tempfile"

class PartitionCoverageReportTest < Minitest::Test
  CRITERION = "pairwise-partitions-v1"

  def setup
    @specifications = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#call" do
        input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    @obligations = SpecProof.plan(@specifications, criterion: CRITERION)
  end

  def test_accepts_category_rows_when_partition_criterion_is_explicit
    report = coverage_document

    validated = SpecProof::CoverageReport.new(report, specifications: @specifications,
                                                      obligations: @obligations, criterion: CRITERION)

    assert_equal report.fetch("missing").map { |row| row.fetch("id") }, validated.missing_ids
    assert_equal CRITERION, validated.criterion
  end

  def test_accepts_legacy_reports_for_readable_partition_policies
    legacy = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#call" do
        input :age, range: 0..120, exhaustive: true, disjoint: true do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :country, values: [:ro, :de]
        combinations :age, :country, all_allowed: true
      end
    RUBY
    legacy_obligations = SpecProof.plan(legacy, criterion: CRITERION)
    report = coverage_document(legacy, legacy_obligations)

    validated = SpecProof::CoverageReport.new(report, specifications: @specifications,
                                                      obligations: @obligations, criterion: CRITERION)

    assert_equal report.fetch("missing").map { |row| row.fetch("id") }, validated.missing_ids
  end

  def test_rejects_partition_reports_when_the_finite_default_is_used
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::CoverageReport.new(coverage_document, specifications: @specifications,
                                                       obligations: @obligations)
    end

    assert_equal "unsupported_coverage_report", error.code
  end

  def test_owns_the_criterion_string_passed_to_the_validator
    criterion = String.new(CRITERION)
    validated = SpecProof::CoverageReport.new(coverage_document, specifications: @specifications,
                                                                 obligations: @obligations,
                                                                 criterion: criterion)
    criterion.replace("pairwise-finite-v1")

    assert_equal CRITERION, validated.criterion
    assert_predicate validated.criterion, :frozen?
  end

  def test_rejects_a_category_bound_change_even_when_its_obligation_id_is_unchanged
    report = coverage_document
    category_typed_values(report).first["upper"] = "18"

    assert_mismatch(report)
  end

  def test_rejects_a_category_name_change_even_when_its_obligation_id_is_unchanged
    report = coverage_document
    category_typed_values(report).first["name"] = "adult"

    assert_mismatch(report)
  end

  def test_rejects_a_native_representative_in_place_of_a_category
    report = coverage_document
    input_values(report).first["age"] = { "kind" => "integer", "value" => "0" }

    assert_mismatch(report)
  end

  def test_rejects_report_when_partition_constraint_changes
    constrained = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#call" do
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
    RUBY
    changed = load_text(<<~RUBY)
      SpecProof.define "AgePolicy#call" do
        input :age, range: 0..120, allow_gaps: false, allow_overlaps: false do
          partition :minor, range: 0...18
          partition :adult, range: 18..120
        end
        input :account, values: [:personal, :business]
        input :country, values: [:ro, :de]
        combinations :age, :account, :country do
          forbid age: in_partition(:adult), account: :business
        end
      end
    RUBY
    constrained_obligations = SpecProof.plan(constrained, criterion: CRITERION)
    changed_obligations = SpecProof.plan(changed, criterion: CRITERION)
    report = coverage_document(constrained, constrained_obligations)

    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::CoverageReport.new(report, specifications: changed,
                                            obligations: changed_obligations, criterion: CRITERION)
    end

    assert_equal "coverage_contract_mismatch", error.code
  end

  private

  def load_text(text)
    Tempfile.create(["partition-report", ".rb"]) do |file|
      file.write(text)
      file.flush
      SpecProof.load([file.path])
    end
  end

  def coverage_document(specifications = @specifications, obligations = @obligations)
    coverage = SpecProof::Coverage.new(obligations: obligations, specifications: specifications)
    coverage.observe(target: "AgePolicy#call", arguments: { age: 16, country: :ro })
    projection = coverage.to_report.transform_keys(&:to_s)
    scope = {
      "ruby_engine" => RUBY_ENGINE, "pid" => Process.pid, "thread" => Thread.current.object_id,
      "window" => "minitest_run", "method_identity" => "direct_owner_definition",
      "input_semantics" => "effective_bound_values", "argument_presence" => "not_observed",
      "targets" => specifications.map(&:target),
      "declaration_sources" => { "specifications" => [], "rbs" => [], "targets" => [] },
      "arguments" => [], "filter" => nil, "exclude" => nil
    }.merge(SpecProof::Report.input_scope(specifications).transform_keys(&:to_s))
    document = {
      "schema_version" => 1, "kind" => "coverage", "errors" => [],
      "contract_digest" => SpecProof::Report.digest(specifications), "criterion" => CRITERION,
      "run_id" => "partition-validation-run", "scope" => scope,
      "evidence_mode" => "obligation_hits", "replay" => false,
      "completion" => "completed", "integrity" => true, "tests_passed" => true
    }.merge(projection.except("status", "completeness"))
    JSON.parse(JSON.generate(document))
  end

  def category_typed_values(report)
    input_values(report).flat_map(&:values).select { |value| value["kind"] == "partition" }
  end

  def input_values(report)
    report.fetch("obligations").map { |row| row.fetch("inputs") }
  end

  def assert_mismatch(report)
    error = assert_raises(SpecProof::ConfigurationError) do
      SpecProof::CoverageReport.new(report, specifications: @specifications,
                                            obligations: @obligations, criterion: CRITERION)
    end
    assert_equal "coverage_contract_mismatch", error.code
  end
end
