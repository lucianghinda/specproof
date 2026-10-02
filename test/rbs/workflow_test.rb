# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

class RBSWorkflowTest < Minitest::Test
  def test_public_load_composes_finite_keyword_inputs_from_rbs_only
    with_inputs do |directory|
      rbs_path = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def eligible?: (?consent: bool?) -> bool
        end
      RBS

      specifications = SpecProof.load([], rbs: [rbs_path], targets: ["Registration#eligible?"])

      assert_equal ["Registration#eligible?"], specifications.map(&:target)
      actual = specifications.first.inputs.map { |name, input| [name, input.domain.values] }
      assert_equal [[:consent, [nil, false, true]]], actual
      assert_equal "rbs", specifications.first.inputs.fetch(:consent).type_sources.first.kind
    end
  end

  def test_rbs_age_refines_dsl_input_and_preserves_all_dsl_targets
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120, exhaustive: true, disjoint: true do
            partition :minor, range: 0..17
            partition :adult, range: 18..120
          end
        end
        SpecProof.define "Registration#archive" do
          input :year, range: 2000..2030
        end
      RUBY
      rbs_path = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def eligible?: (age: Integer, ?consent: bool?) -> bool
        end
      RBS

      specifications = SpecProof.load([dsl], rbs: [rbs_path], targets: ["Registration#eligible?"])
      obligations = SpecProof.plan(specifications)
      assert_equal %w[Registration#archive Registration#eligible?], specifications.map(&:target).sort
      assert_empty SpecProof.check(specifications)
      count = obligations.count { |item| item.target == "Registration#eligible?" }
      assert_equal 9, count
      assert_includes obligations.map(&:value), nil
    end
  end

  def test_explicit_and_composed_contracts_have_same_semantic_digest_and_obligations
    with_inputs do |directory|
      explicit = write(directory, "explicit.rb", <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120, exhaustive: true, disjoint: true do
            partition :minor, range: 0..17
            partition :adult, range: 18..120
          end
          input :consent, values: [nil, false, true]
        end
      RUBY
      partial = write(directory, "partial.rb", <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120, exhaustive: true, disjoint: true do
            partition :minor, range: 0..17
            partition :adult, range: 18..120
          end
        end
      RUBY
      rbs_path = write(directory, "types.rbs", <<~RBS)
        class Registration
          def eligible?: (age: Integer, ?consent: bool?) -> bool
        end
      RBS
      moved_rbs = write(directory, "moved-types.rbs", ["# relocated signature", "", File.read(rbs_path)].join("\n"))

      full_specs = SpecProof.load([explicit])
      composed_specs = SpecProof.load([partial], rbs: [rbs_path], targets: ["Registration#eligible?"])
      moved_composed_specs = SpecProof.load([partial], rbs: [moved_rbs], targets: ["Registration#eligible?"])
      assert_equal SpecProof::Report.digest(full_specs), SpecProof::Report.digest(composed_specs)
      assert_equal SpecProof::Report.digest(composed_specs), SpecProof::Report.digest(moved_composed_specs)
      assert_equal semantic_obligations(SpecProof.plan(full_specs)),
                   semantic_obligations(SpecProof.plan(composed_specs))
      assert_equal semantic_obligations(SpecProof.plan(composed_specs)),
                   semantic_obligations(SpecProof.plan(moved_composed_specs))
      full_age = full_specs.first.inputs.fetch(:age)
      composed_age = composed_specs.first.inputs.fetch(:age)
      assert_equal [full_age.exhaustive, full_age.disjoint], [composed_age.exhaustive, composed_age.disjoint]
      assert_equal [true, true], [composed_age.exhaustive, composed_age.disjoint]
      count = SpecProof.plan(composed_specs).count { |item| item.target == "Registration#eligible?" }
      assert_equal 9, count
      full_sources = SpecProof.plan(full_specs).flat_map(&:sources).uniq.map(&:path).sort
      composed_sources = SpecProof.plan(composed_specs).flat_map(&:sources).uniq.map(&:path).sort
      refute_equal full_sources, composed_sources
      eligible = composed_specs.find { |item| item.target == "Registration#eligible?" }
      assert_equal "rbs", eligible.inputs.fetch(:age).type_sources.first.kind
      moved_eligible = moved_composed_specs.find { |item| item.target == "Registration#eligible?" }
      original_source = eligible.inputs.fetch(:age).type_sources.first
      moved_source = moved_eligible.inputs.fetch(:age).type_sources.first
      refute_equal [original_source.path, original_source.line], [moved_source.path, moved_source.line]
      assert_equal original_source.line + 2, moved_source.line
    end
  end

  def test_source_order_file_moves_and_line_moves_do_not_change_the_contract_digest
    with_inputs do |directory|
      first = write(directory, "first.rb", <<~RUBY)
        SpecProof.define "Feature#enabled?" do
          input :enabled, values: [false, true]
        end
      RUBY
      moved = write(directory, "moved.rb", ["# moved declaration", "", File.read(first)].join("\n"))
      other = write(directory, "other.rb", <<~RUBY)
        SpecProof.define "Feature#count" do
          input :count, range: 0..10
        end
      RUBY

      first_specs = SpecProof.load([first, other])
      moved_specs = SpecProof.load([other, moved])
      assert_equal SpecProof::Report.digest(first_specs), SpecProof::Report.digest(moved_specs)
    end
  end

  def test_nullable_integer_refinement_can_retain_nil
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          input :value, values: [nil, 1, 2]
        end
      RUBY
      rbs = write(directory, "types.rbs", "class Registration\n def save: (Integer? value) -> void\nend\n")

      specifications = SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"])
      assert_empty SpecProof.check(specifications)
      assert_equal [nil, 1, 2], specifications.first.inputs.fetch(:value).domain.values
    end
  end

  def test_load_validates_rbs_option_pairs_and_duplicate_paths_and_targets
    with_inputs do |directory|
      rbs_path = write(directory, "types.rbs", "class Registration\n def save: (Integer age) -> void\nend\n")
      alias_path = File.join(directory, "alias.rbs")
      File.symlink(rbs_path, alias_path)

      assert_code("targets_required") { SpecProof.load([], rbs: [rbs_path]) }
      assert_code("rbs_without_paths") { SpecProof.load([], targets: ["Registration#save"]) }
      assert_code("duplicate_path") do
        SpecProof.load([], rbs: [rbs_path, alias_path], targets: ["Registration#save"])
      end
      dsl_alias = File.join(directory, "signature.rb")
      File.symlink(rbs_path, dsl_alias)
      assert_code("duplicate_path") do
        SpecProof.load([dsl_alias], rbs: [rbs_path], targets: ["Registration#save"])
      end
      assert_code("duplicate_target") do
        SpecProof.load([], rbs: [rbs_path], targets: ["Registration#save", "Registration#save"])
      end
      assert_code("invalid_target") do
        SpecProof.load([], rbs: [rbs_path], targets: ["Registration.save"])
      end
    end
  end

  def test_unbounded_integer_and_conflicting_refinement_have_configuration_and_semantic_errors
    with_inputs do |directory|
      rbs_path = write(directory, "types.rbs", "class Registration\n def save: (Integer age) -> void\nend\n")
      assert_code("domain_refinement_required") do
        SpecProof.load([], rbs: [rbs_path], targets: ["Registration#save"])
      end

      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          input :age, range: 0..4
        end
      RUBY
      bool_rbs = write(directory, "bool.rbs", "class Registration\n def save: (bool age) -> void\nend\n")
      specs = SpecProof.load([dsl], rbs: [bool_rbs], targets: ["Registration#save"])
      finding = SpecProof.check(specs).fetch(0)
      assert_equal :type_domain_conflict, finding.code
      assert_equal 0, finding.witness
      assert_equal %w[dsl rbs], finding.sources.map(&:kind).sort
      assert_equal 2, finding.sources.length
      assert_raises(SpecProof::InvalidSpecificationError) { SpecProof.plan(specs) }
    end
  end

  def test_cli_accepts_repeated_rbs_and_target_options_and_emits_single_json_document
    with_inputs do |directory|
      first = write(directory, "first.rbs", "class Registration\n def save: (bool age) -> void\nend\n")
      second = write(directory, "second.rbs", "class Feature\n def enabled?: (bool enabled) -> void\nend\n")
      out, err, status = invoke("check", "--rbs", first, "--rbs", second, "--target", "Registration#save",
                                "--target", "Feature#enabled?", "--format", "json")
      assert status.success?, err
      assert_empty err
      parsed = JSON.parse(out)
      assert_equal "check", parsed.fetch("kind")
      assert_empty parsed.fetch("findings")
    end
  end

  def test_cli_rbs_plan_has_nine_candidates_and_semantic_conflict_is_exit_one
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 0..120 do
            partition :minor, range: 0..17
            partition :adult, range: 18..120
          end
        end
      RUBY
      rbs_path = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def eligible?: (age: Integer, ?consent: bool?) -> bool
        end
      RBS
      out, err, status = invoke("plan", dsl, "--rbs", rbs_path, "--target", "Registration#eligible?", "--format",
                                "json")
      assert status.success?, err
      count = JSON.parse(out).fetch("obligations").count do |item|
        item.fetch("target") == "Registration#eligible?"
      end
      assert_equal 9, count

      conflict = write(directory, "conflict.rbs", "class Registration\n def save: (true value) -> void\nend\n")
      range = write(directory, "range.rb", "SpecProof.define 'Registration#save' do\n input :value, range: 1..3\nend\n")
      out, err, status = invoke("plan", range, "--rbs", conflict, "--target", "Registration#save", "--format",
                                "json")
      assert_equal 1, status.exitstatus, err
      finding = JSON.parse(out).fetch("findings").fetch(0)
      assert_equal "type_domain_conflict", finding.fetch("code")
      assert_equal({ "kind" => "integer", "value" => "1" }, finding.fetch("witness"))
      assert_empty JSON.parse(out).fetch("obligations")
      assert_equal %w[dsl rbs], finding.fetch("sources").map { |source| source.fetch("kind") }.sort

      out, err, status = invoke("check", range, "--rbs", conflict, "--target", "Registration#save", "--format",
                                "json")
      assert_equal 1, status.exitstatus, err
      assert_equal "type_domain_conflict", JSON.parse(out).fetch("findings").fetch(0).fetch("code")
    end
  end

  def test_cli_reports_malformed_and_unsupported_rbs_as_configuration_errors
    with_inputs do |directory|
      malformed = write(directory, "malformed.rbs", "class Registration\n def save: (Integer value\nend\n")
      unsupported = write(directory, "unsupported.rbs", "class Registration\n def save: (String value) -> void\nend\n")

      { malformed => "rbs_parse_error", unsupported => "unsupported_rbs_type" }.each do |path, code|
        out, _err, status = invoke("check", "--rbs", path, "--target", "Registration#save", "--format", "json")
        assert_equal 2, status.exitstatus
        error = JSON.parse(out).fetch("errors").fetch(0)
        assert_equal code, error.fetch("code")
        assert_equal "rbs", error.fetch("source").fetch("kind")
      end
    end
  end

  def test_cli_keeps_json_after_missing_option_values_and_rejects_unknown_options
    [["--rbs", "--format", "json"], ["--target", "--format", "json"],
     ["--mystery", "--format", "json"]].each do |args|
      out, err, status = invoke("check", *args)
      assert_equal 2, status.exitstatus
      assert_empty err
      payload = JSON.parse(out)
      expected = args.first == "--mystery" ? "unsupported_option" : "missing_option_value"
      assert_equal expected, payload.fetch("errors").fetch(0).fetch("code")
    end
  end

  def test_cli_configuration_errors_have_stable_codes_and_duplicate_dsl_targets_stay_rejected
    with_inputs do |directory|
      dsl = write(directory, "duplicate.rb", <<~RUBY)
        2.times do
          SpecProof.define "Registration#save" do
            input :value, values: [true]
          end
        end
      RUBY
      rbs = write(directory, "types.rbs", "class Registration\n def save: (bool value) -> void\nend\n")
      out, _err, status = invoke("check", dsl, "--rbs", rbs, "--target", "Registration#save", "--format", "json")
      assert_equal 2, status.exitstatus
      assert_equal "duplicate_target", JSON.parse(out).fetch("errors").fetch(0).fetch("code")
    end
  end

  private

  def with_inputs(&)
    Dir.mktmpdir("specproof-rbs-workflow-", "/private/tmp", &)
  end

  def write(directory, name, contents)
    path = File.join(directory, name)
    File.write(path, contents)
    path
  end

  def assert_code(code, &)
    error = assert_raises(SpecProof::ConfigurationError, &)
    assert_equal code, error.code
  end

  def semantic_obligations(obligations)
    obligations.map { |item| [item.id, item.target, item.input, item.value, item.reasons] }
  end

  def invoke(*)
    Open3.capture3(RbConfig.ruby, "-Ilib", "exe/specproof", *)
  end
end
