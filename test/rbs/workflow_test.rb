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

  def test_excluded_hash_input_is_skipped_while_finite_sibling_is_composed
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          exclude_input :payload, reason: "Payload contents outside file-ID scope"
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (payload: Hash[String, untyped], active: bool) -> void
        end
      RBS

      specification = SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"]).fetch(0)

      assert_equal [:active], specification.inputs.keys
      assert_equal [false, true], specification.inputs.fetch(:active).domain.values
      assert_equal "Payload contents outside file-ID scope", specification.exclusions.fetch(:payload).reason
    end
  end

  def test_excluded_name_must_exist_in_full_rbs_signature
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          exclude_input :paylod, reason: "Outside selected scope"
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (payload: Hash[String, untyped]) -> void
        end
      RBS

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"])
      end

      assert_equal "rbs_input_mismatch", error.code
      assert_includes error.message, "paylod"
    end
  end

  def test_unknown_analyzed_name_is_rejected_when_all_rbs_facts_are_excluded
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          exclude_input :payload, reason: "Outside selected scope"
          input :bogus, values: [1]
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (payload: Hash[String, untyped]) -> void
        end
      RBS

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"])
      end

      assert_equal "rbs_input_mismatch", error.code
      assert_includes error.message, "bogus"
    end
  end

  def test_all_excluded_mixed_target_is_rejected
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          exclude_input :payload, reason: "Outside selected scope"
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (payload: Hash[String, untyped]) -> void
        end
      RBS

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"])
      end

      assert_equal "inputs_required", error.code
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

  def test_public_load_rejects_dsl_inputs_missing_from_selected_rbs_target
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          input :enabled, values: [false, true]
          input :bogus, values: [1, 2]
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (enabled: bool) -> void
        end
      RBS

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof.load([dsl], rbs: [rbs], targets: ["Registration#save"])
      end

      assert_equal "rbs_input_mismatch", error.code
      assert_equal File.realpath(dsl), error.path
      assert_equal [File.realpath(dsl), 3, "dsl"], [error.source.path, error.source.line, error.source.kind]
      assert_includes error.message, "Registration#save"
      assert_includes error.message, "bogus"
      assert_includes error.message, "#{File.realpath(rbs)}:2"
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

  def test_cli_rbs_input_mismatch_is_configuration_error_without_plan_obligations
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          input :enabled, values: [false, true]
          input :bogus, values: [1, 2]
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (enabled: bool) -> void
        end
      RBS

      %w[check plan].each do |command|
        out, err, status = invoke(command, dsl, "--rbs", rbs, "--target", "Registration#save", "--format", "json")

        assert_equal 2, status.exitstatus, err
        assert_empty err
        payload = JSON.parse(out)
        error = payload.fetch("errors").fetch(0)
        assert_equal "rbs_input_mismatch", error.fetch("code")
        assert_equal File.realpath(dsl), error.fetch("path")
        assert_equal File.realpath(dsl), error.dig("source", "path")
        assert_equal 3, error.dig("source", "line")
        assert_includes error.fetch("message"), "Registration#save"
        assert_includes error.fetch("message"), "bogus"
        assert_includes error.fetch("message"), "#{File.realpath(rbs)}:2"
        assert_empty payload.fetch("obligations", []) if command == "plan"
      end
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

  def test_minitest_collects_the_composed_rbs_and_dsl_domain
    with_inputs do |directory|
      dsl, rbs = registration_sources(directory)
      offline = invoke("plan", dsl, "--rbs", rbs, "--target", "Registration#eligible?", "--format", "json")
      assert offline[2].success?, offline[1]
      planned = JSON.parse(offline[0])
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_minitest(
        directory, specifications: [dsl], rbs: [rbs], targets: ["Registration#eligible?"],
                   report_path: report_path, test_body: <<~RUBY
                     policy = Registration.new
                     assert_equal false, policy.eligible?(age: 0, consent: true)
                     assert_equal false, policy.eligible?(age: 1, consent: true)
                     assert_equal false, policy.eligible?(age: 17, consent: true)
                     assert_equal true, policy.eligible?(age: 18, consent: true)
                     assert_equal true, policy.eligible?(age: 119, consent: true)
                     assert_equal true, policy.eligible?(age: 120, consent: true)
                     assert_equal false, policy.eligible?(age: 18, consent: nil)
                     assert_equal false, policy.eligible?(age: 18, consent: false)
                     assert_equal false, policy.eligible?(age: 18)
                   RUBY
      )

      assert status.success?, stderr + stdout
      report = JSON.parse(File.read(report_path))
      assert_equal "completed", report.fetch("completion")
      assert_equal true, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
      assert_equal planned.fetch("contract_digest"), report.fetch("contract_digest")
      assert_equal planned.fetch("obligations").map { |row| row.fetch("id") }.sort,
                   report.fetch("obligations").map { |row| row.fetch("id") }.sort
      assert_equal ["Registration#eligible?"], report.dig("scope", "targets")
      assert_equal [File.realpath(dsl)], report.dig("scope", "declaration_sources", "specifications")
      assert_equal [File.realpath(rbs)], report.dig("scope", "declaration_sources", "rbs")
      assert_equal ["Registration#eligible?"], report.dig("scope", "declaration_sources", "targets")
      assert_equal 9, report.fetch("exercised_count")
      assert_equal 0, report.fetch("missing_count")
      assert(report.fetch("obligations").all? { |row| row.fetch("status") == "exercised" })
      nil_consent = report.fetch("obligations").find do |row|
        row.fetch("input") == "consent" && row.dig("value", "kind") == "nil"
      end
      assert_equal 2, nil_consent.fetch("hits")
      assert_includes stdout, "9/9 obligations exercised"
    end
  end

  def test_offline_and_runtime_reports_share_excluded_input_scope_and_identity
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#save" do
          input :active, values: [false, true]
          exclude_input :payload, reason: "Payload contents outside file-ID scope"
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def save: (payload: Hash[String, untyped], active: bool) -> bool
        end
      RBS
      offline = JSON.parse(invoke("plan", dsl, "--rbs", rbs, "--target", "Registration#save", "--format", "json").first)
      report_path = File.join(directory, "coverage.json")
      options = {
        specifications: [dsl], rbs: [rbs], targets: ["Registration#save"], report_path: report_path,
        method_body: "def save(payload:, active:) = active",
        test_body: "assert Registration.new.save(payload: { secret: Object.new }, active: true)"
      }
      stdout, stderr, status = run_minitest(
        directory, **options
      )

      assert status.success?, stderr + stdout
      runtime = JSON.parse(File.read(report_path))
      assert_equal offline.fetch("contract_digest"), runtime.fetch("contract_digest")
      assert_equal offline.fetch("obligations").map { |row| row.fetch("id") }.sort,
                   runtime.fetch("obligations").map { |row| row.fetch("id") }.sort
      assert_equal offline.fetch("scope"), runtime.fetch("scope").slice("completeness_scope", "input_scope")
      exclusion = runtime.dig("scope", "input_scope", 0, "excluded_inputs", 0)
      assert_equal "Payload contents outside file-ID scope", exclusion.fetch("reason")
      assert_includes stdout, "payload (Payload contents outside file-ID scope)"
    end
  end

  def test_selected_nonprimitive_marks_only_analyzed_scope_incomplete
    with_inputs do |directory|
      dsl, rbs = selection_sources(directory)
      report_path = File.join(directory, "coverage.json")
      options = {
        specifications: [dsl], rbs: [rbs], targets: ["Registration#save"], report_path: report_path,
        method_body: "def save(payload:, active:) = true",
        test_body: "assert Registration.new.save(payload: Object.new, active: Object.new)"
      }
      _stdout, _stderr, _status = run_minitest(
        directory, **options
      )

      report = JSON.parse(File.read(report_path))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal "non_primitive_argument", report.fetch("errors").fetch(0).fetch("code")
      assert_equal "analyzed_inputs", report.dig("scope", "completeness_scope")
    end
  end

  def test_excluded_binding_does_not_mask_original_target_test_failure
    with_inputs do |directory|
      dsl, rbs = selection_sources(directory)
      report_path = File.join(directory, "coverage.json")
      options = {
        specifications: [dsl], rbs: [rbs], targets: ["Registration#save"], report_path: report_path,
        method_body: "def save(payload:, active:) = raise('original target failure')",
        test_body: "Registration.new.save(payload: Object.new, active: true)"
      }
      stdout, _stderr, status = run_minitest(
        directory, **options
      )

      report = JSON.parse(File.read(report_path))
      assert_equal 1, status.exitstatus
      assert_includes stdout, "original target failure"
      assert_equal false, report.fetch("tests_passed")
      assert_empty report.fetch("errors")
    end
  end

  def test_minitest_filtered_rbs_run_reports_missing_boundary_and_fresh_run_identity
    with_inputs do |directory|
      dsl, rbs = registration_sources(directory)
      report_path = File.join(directory, "coverage.json")
      arguments = { specifications: [dsl], rbs: [rbs], targets: ["Registration#eligible?"],
                    report_path: report_path }
      first_out, first_err, first_status = run_minitest(
        directory, **arguments,
        test_body: "assert_equal false, Registration.new.eligible?(age: 0, consent: false)"
      )
      assert first_status.success?, first_err + first_out
      first_report = JSON.parse(File.read(report_path))
      assert_equal 2, first_report.fetch("exercised_count")
      assert_equal 7, first_report.fetch("missing_count")
      missing_age_values = first_report.fetch("missing").filter_map do |row|
        row.dig("value", "value") if row.fetch("input") == "age"
      end
      assert_includes missing_age_values, "18"

      second_out, second_err, second_status = run_minitest(
        directory, **arguments,
        test_body: "assert_equal true, Registration.new.eligible?(age: 18, consent: true)\n" \
                   "assert_equal false, Registration.new.eligible?(age: 0)"
      )
      assert second_status.success?, second_err + second_out
      second_report = JSON.parse(File.read(report_path))
      refute_equal first_report.fetch("run_id"), second_report.fetch("run_id")
      assert_equal first_report.fetch("contract_digest"), second_report.fetch("contract_digest")
      assert_equal first_report.fetch("obligations").map { |row| row.fetch("id") }.sort,
                   second_report.fetch("obligations").map { |row| row.fetch("id") }.sort
      assert_equal 4, second_report.fetch("exercised_count")
    end
  end

  def test_minitest_accepts_rbs_only_selection_with_empty_specifications
    with_inputs do |directory|
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def ready?: (bool enabled) -> bool
        end
      RBS
      report_path = File.join(directory, "coverage.json")
      test_body = <<~RUBY
        assert Registration.new.ready?(enabled: true)
        refute Registration.new.ready?(enabled: false)
      RUBY
      stdout, stderr, status = run_minitest(
        directory, specifications: [], rbs: [rbs], targets: ["Registration#ready?"], report_path: report_path,
                   test_body: test_body, method_body: "def ready?(enabled:) = enabled", mutate_options: true
      )

      assert status.success?, stderr + stdout
      report = JSON.parse(File.read(report_path))
      assert_equal 2, report.fetch("obligation_count")
      assert_equal [File.realpath(rbs)], report.dig("scope", "declaration_sources", "rbs")
      assert_equal [], report.dig("scope", "declaration_sources", "specifications")
    end
  end

  def test_minitest_keeps_unselected_dsl_targets_in_runtime_scope
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#eligible?" do
          input :age, range: 18..19
        end
        SpecProof.define "Registration#archive?" do
          input :year, range: 2000..2001
        end
      RUBY
      rbs = write(directory, "registration.rbs", <<~RBS)
        class Registration
          def eligible?: (age: Integer) -> bool
        end
      RBS
      report_path = File.join(directory, "coverage.json")
      stdout, stderr, status = run_minitest(
        directory, specifications: [dsl], rbs: [rbs], targets: ["Registration#eligible?"],
                   report_path: report_path, method_body: <<~RUBY, test_body: <<~RUBY
                     def eligible?(age:) = age >= 18
                     def archive?(year:) = year < 2001
                   RUBY
                     assert Registration.new.eligible?(age: 18)
                     assert Registration.new.archive?(year: 2000)
                   RUBY
      )

      assert status.success?, stderr + stdout
      report = JSON.parse(File.read(report_path))
      assert_equal %w[Registration#archive? Registration#eligible?], report.dig("scope", "targets")
      archive_rows = report.fetch("obligations").select { |row| row.fetch("target") == "Registration#archive?" }
      assert_equal(1, archive_rows.count { |row| row.fetch("status") == "exercised" })
      assert_equal(1, archive_rows.count { |row| row.fetch("status") == "not_observed" })
    end
  end

  def test_minitest_rbs_preparation_errors_write_incomplete_report_and_preserve_test_result
    with_inputs do |directory|
      dsl, rbs = registration_sources(directory)
      integer_rbs = write(directory, "unbounded.rbs", <<~RBS)
        class Registration
          def ready?: (Integer age) -> bool
        end
      RBS
      mismatch_rbs = write(directory, "typed.rbs", <<~RBS)
        class Registration
          def ready?: (bool enabled) -> bool
        end
      RBS
      mismatch_dsl = write(directory, "ready.rb", <<~RUBY)
        SpecProof.define "Registration#ready?" do
          input :enabled, values: [false, true]
        end
      RUBY
      conflict_rbs = write(directory, "conflict.rbs", <<~RBS)
        class Registration
          def eligible?: (bool age, ?consent: bool?) -> bool
        end
      RBS
      malformed_rbs = write(directory, "malformed.rbs", <<~RBS)
        class Registration
          def eligible?: (age: Integer
        end
      RBS
      cases = {
        missing: { specifications: [dsl], rbs: [File.join(directory, "absent.rbs")],
                   targets: ["Registration#eligible?"] },
        integer: { specifications: [], rbs: [integer_rbs],
                   targets: ["Registration#ready?"] },
        mismatch: { rbs: [mismatch_rbs],
                    targets: ["Registration#ready?"],
                    specifications: [mismatch_dsl],
                    method_body: "def ready?(active:) = active" },
        conflict: { specifications: [dsl], rbs: [conflict_rbs],
                    targets: ["Registration#eligible?"] },
        malformed: { specifications: [dsl], rbs: [malformed_rbs], targets: ["Registration#eligible?"] },
        unavailable: { specifications: [dsl], rbs: [rbs], targets: ["Registration#eligible?"], disable_rbs: true }
      }
      error_codes = { missing: "file_not_found", integer: "domain_refinement_required",
                      mismatch: "parameter_mismatch", conflict: "type_domain_conflict",
                      malformed: "rbs_parse_error", unavailable: "rbs_dependency_missing" }
      cases.each do |name, options|
        report_path = File.join(directory, "#{name}.json")
        expected_method = options.delete(:method_body)
        disable_rbs = options.delete(:disable_rbs) || false
        _stdout, _stderr, status = run_minitest(
          directory, **options, method_body: expected_method, disable_rbs: disable_rbs, report_path: report_path,
                                test_body: "assert_equal 2, 1"
        )
        refute status.success?, "#{name} setup error must fail despite the runner's assertion failure"
        report = JSON.parse(File.read(report_path))
        assert_equal "incomplete", report.fetch("completion")
        assert_equal false, report.fetch("integrity")
        assert_equal false, report.fetch("tests_passed")
        refute_equal "completed", report.fetch("completion")
        refute_empty report.fetch("errors")
        assert_equal error_codes.fetch(name), report.fetch("errors").first.fetch("code")
        if name == :missing
          assert_equal File.expand_path(File.join(directory, "absent.rbs")), report.fetch("errors").first.fetch("path")
        end
        if name == :malformed
          assert_equal 4, report.fetch("errors").first.dig("source", "line")
          assert_equal File.realpath(malformed_rbs), report.fetch("errors").first.dig("source", "path")
        end
      end
    end
  end

  def test_minitest_requires_a_complete_rbs_keyword_parameter_match
    with_inputs do |directory|
      dsl = write(directory, "policy.rb",
                  "SpecProof.define 'Registration#ready?' do\n input :enabled, values: [false, true]\nend\n")
      rbs = write(directory, "types.rbs", "class Registration\n def ready?: (bool enabled) -> bool\nend\n")
      _stdout, _stderr, status = run_minitest(
        directory, specifications: [dsl], rbs: [rbs], targets: ["Registration#ready?"],
                   report_path: File.join(directory, "report.json"),
                   method_body: "def ready?(active:) = active", test_body: "assert true"
      )
      refute status.success?
      report = JSON.parse(File.read(File.join(directory, "report.json")))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
    end
  end

  def test_minitest_rbs_input_mismatch_keeps_original_tests_running_and_report_incomplete
    with_inputs do |directory|
      dsl = write(directory, "policy.rb", <<~RUBY)
        SpecProof.define "Registration#ready?" do
          input :enabled, values: [false, true]
          input :bogus, values: [1, 2]
        end
      RUBY
      rbs = write(directory, "types.rbs", "class Registration\n def ready?: (bool enabled) -> bool\nend\n")
      report_path = File.join(directory, "report.json")

      stdout, stderr, status = run_minitest(
        directory, specifications: [dsl], rbs: [rbs], targets: ["Registration#ready?"],
                   report_path: report_path, method_body: "def ready?(enabled:, **_options) = enabled",
                   test_body: "assert Registration.new.ready?(enabled: true, bogus: 1)"
      )

      refute status.success?, stderr + stdout
      report = JSON.parse(File.read(report_path))
      assert_equal "incomplete", report.fetch("completion")
      assert_equal false, report.fetch("integrity")
      assert_equal true, report.fetch("tests_passed")
      assert_equal "rbs_input_mismatch", report.fetch("errors").first.fetch("code")
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

  def registration_sources(directory)
    dsl = write(directory, "policy.rb", <<~RUBY)
      SpecProof.define "Registration#eligible?" do
        input :age, range: 0..120, exhaustive: true, disjoint: true do
          partition :minor, range: 0..17
          partition :adult, range: 18..120
        end
      end
    RUBY
    rbs = write(directory, "registration.rbs", <<~RBS)
      class Registration
        def eligible?: (age: Integer, ?consent: bool?) -> bool
      end
    RBS
    [dsl, rbs]
  end

  def selection_sources(directory)
    dsl = write(directory, "selection.rb", <<~RUBY)
      SpecProof.define "Registration#save" do
        input :active, values: [false, true]
        exclude_input :payload, reason: "Payload outside scope"
      end
    RUBY
    rbs = write(directory, "selection.rbs", <<~RBS)
      class Registration
        def save: (payload: Hash[String, untyped], active: bool) -> bool
      end
    RBS
    [dsl, rbs]
  end

  def run_minitest(directory, specifications:, report_path:, test_body:, rbs: [], targets: [], method_body: nil,
                   disable_rbs: false, mutate_options: false)
    method_body ||= "def eligible?(age:, consent: nil) = age >= 18 && consent == true"
    script = <<~RUBY
      gem "minitest", "~> 5.26.2"
      $LOAD_PATH.unshift ENV.fetch("SPECPROOF_LIB")
      require "specproof"
      require "minitest/autorun"
      class Registration
        #{method_body}
      end
      class RuntimeCoverageTest < Minitest::Test
        def test_values
          #{test_body.gsub("\n", "\n          ").strip}
        end
      end
      require "specproof/minitest"
      if ENV.fetch("DISABLE_RBS") == "1"
        Kernel.prepend(Module.new do
          def require(path)
            raise LoadError, "simulated missing RBS" if path == "rbs"

            super
          end
        end)
      end
      specification_paths = ENV.fetch("SPEC_PATHS").split(File::PATH_SEPARATOR)
      rbs_paths = ENV.fetch("RBS_PATHS").split(File::PATH_SEPARATOR)
      selected_targets = ENV.fetch("TARGETS").split(File::PATH_SEPARATOR)
      SpecProof::Minitest.install!(specifications: specification_paths, rbs: rbs_paths, targets: selected_targets,
                                  output: ENV.fetch("REPORT_PATH"))
      if ENV.fetch("MUTATE_OPTIONS") == "1"
        [specification_paths, rbs_paths, selected_targets].each do |values|
          values.each { |value| value.replace("mutated") }
          values.clear
        end
      end
    RUBY
    env = {
      "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil,
      "BUNDLE_BIN_PATH" => nil, "BUNDLER_SETUP" => nil, "BUNDLER_VERSION" => nil,
      "MT_NO_PLUGINS" => "1", "SPECPROOF_LIB" => File.expand_path("../../lib", __dir__),
      "SPEC_PATHS" => specifications.join(File::PATH_SEPARATOR), "RBS_PATHS" => rbs.join(File::PATH_SEPARATOR),
      "TARGETS" => targets.join(File::PATH_SEPARATOR), "REPORT_PATH" => report_path,
      "DISABLE_RBS" => disable_rbs ? "1" : "0", "MUTATE_OPTIONS" => mutate_options ? "1" : "0"
    }
    Open3.capture3(env, RbConfig.ruby, "-e", script, chdir: directory)
  end
end
