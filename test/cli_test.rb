# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "json"
require "tempfile"
require "tmpdir"
require "fileutils"

class CliTest < Minitest::Test
  def test_version
    out, err, status = invoke("--version")
    assert status.success?, err
    assert_equal "SpecProof 0.1.0\n", out
    assert_empty err
  end

  def test_unknown_command_prints_usage_and_exits_two
    out, err, status = invoke("bogus")
    assert_equal 2, status.exitstatus
    assert_empty out
    assert_match(/Usage:/, err)
  end

  def test_unknown_command_json_is_one_error_document
    out, err, status = invoke("bogus", "--format", "json")
    assert_equal 2, status.exitstatus
    assert_empty err
    payload = JSON.parse(out)
    assert_equal "error", payload.fetch("kind")
    assert_equal "unknown_command", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_check_json_is_one_deterministic_document
    args = ["check", fixture("age_policy.rb"), "--format", "json"]
    first, err, status = invoke(*args)
    second, _, second_status = invoke(*args)
    assert status.success?, err
    assert second_status.success?
    assert_equal first, second
    parsed = JSON.parse(first)
    assert_equal "check", parsed.fetch("kind")
    assert_empty parsed.fetch("findings")
  end

  def test_semantic_error_is_json_with_exit_one
    out, err, status = invoke("check", fixture("age_gap.rb"), "--format", "json")
    assert_equal 1, status.exitstatus, err
    result = JSON.parse(out)
    assert_equal "partition_gap", result.fetch("findings").fetch(0).fetch("code")
  end

  def test_plan_json_reports_typed_values_and_digest
    out, err, status = invoke("plan", fixture("age_policy.rb"), "--format", "json")
    repeated, repeated_err, repeated_status = invoke("plan", fixture("age_policy.rb"), "--format", "json")
    assert status.success?, err
    assert repeated_status.success?, repeated_err
    assert_equal out, repeated
    result = JSON.parse(out)
    assert_equal "plan", result.fetch("kind")
    assert_equal "input-basics-v1", result.fetch("criterion")
    assert_equal "integer", result.fetch("obligations").fetch(0).fetch("value").fetch("kind")
    assert_match(/\A[0-9a-f]{64}\z/, result.fetch("contract_digest"))
  end

  def test_json_configuration_error_is_one_document
    out, _err, status = invoke("check", "/missing/specification.rb", "--format", "json")
    assert_equal 2, status.exitstatus
    payload = JSON.parse(out)
    assert_equal "check", payload.fetch("kind")
    assert_equal "file_not_found", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_malformed_file_error_keeps_requested_kind_and_exit_two
    Tempfile.create(["specproof-bad", ".rb"]) do |file|
      file.write("this is not valid Ruby !\n")
      file.flush
      out, _err, status = invoke("check", file.path, "--format", "json")
      assert_equal 2, status.exitstatus
      payload = JSON.parse(out)
      assert_equal "check", payload.fetch("kind")
      assert_equal "syntax_error", payload.fetch("errors").fetch(0).fetch("code")
    end
  end

  def test_unsupported_option_is_a_json_error
    out, _err, status = invoke("plan", fixture("age_policy.rb"), "--format", "json", "--unknown")
    assert_equal 2, status.exitstatus
    payload = JSON.parse(out)
    assert_equal "plan", payload.fetch("kind")
    assert_equal "unsupported_option", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_json_format_after_an_invalid_option_still_returns_one_error_document
    out, err, status = invoke("check", "--unknown", "--format", "json")
    assert_equal 2, status.exitstatus
    assert_empty err
    payload = JSON.parse(out)
    assert_equal "check", payload.fetch("kind")
    assert_equal "unsupported_option", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_specification_stdout_is_redirected_during_json_loading
    Tempfile.create(["specproof", ".rb"]) do |file|
      file.write("puts 'loader noise'\nSpecProof.define 'Example#call' do\n  input :value, values: [1]\nend\n")
      file.flush
      out, err, status = invoke("check", file.path, "--format", "json")
      assert status.success?, err
      assert_equal "loader noise\n", err
      assert_equal "check", JSON.parse(out).fetch("kind")
    end
  end

  def test_requiring_core_does_not_load_minitest
    script = 'require "specproof"; print $LOADED_FEATURES.any? { |path| path.include?("minitest") }'
    out, err, status = Open3.capture3(RbConfig.ruby, "-Ilib", "-e", script)
    assert status.success?, err
    assert_equal "false", out
  end

  def test_skill_export_requires_explicit_destination_in_json_mode
    out, err, status = invoke("skills", "export", "--format", "json")
    assert_equal 2, status.exitstatus
    assert_empty err
    payload = JSON.parse(out)
    assert_equal "skills_export", payload.fetch("kind")
    assert_equal 1, payload.fetch("schema_version")
    assert_equal "0.1.0", payload.fetch("specproof_version")
    assert_equal "missing_skills_destination", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_skill_export_missing_to_value_still_recognizes_later_json_flag
    out, err, status = invoke("skills", "export", "--to", "--format", "json")
    assert_equal 2, status.exitstatus
    assert_empty err
    payload = JSON.parse(out)
    assert_equal "skills_export", payload.fetch("kind")
    assert_equal "missing_skills_destination", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_skill_export_reports_bad_options_even_when_json_format_follows
    out, err, status = invoke("skills", "export", "--to", "tmp/out", "--bad", "--format", "json")
    assert_equal 2, status.exitstatus
    assert_empty err
    payload = JSON.parse(out)
    assert_equal "skills_export", payload.fetch("kind")
    assert_equal "unsupported_option", payload.fetch("errors").fetch(0).fetch("code")
  end

  def test_skill_export_writes_a_stable_success_report_and_is_idempotent
    Dir.mktmpdir("specproof-cli-") do |directory|
      directory = File.realpath(directory)
      destination = File.join(directory, "client-skills")
      out, err, status = invoke("skills", "export", "--to", destination, "--format", "json")
      assert status.success?, err
      first = JSON.parse(out)
      assert_equal "skills_export", first.fetch("kind")
      assert_empty first.fetch("errors")
      assert_equal File.expand_path(destination), first.fetch("destination")
      assert_equal [], first.fetch("unchanged")
      assert_equal packaged_skill_files(destination), first.fetch("exported")

      repeated, repeated_err, repeated_status = invoke("skills", "export", "--to", destination, "--format", "json")
      assert repeated_status.success?, repeated_err
      second = JSON.parse(repeated)
      assert_equal [], second.fetch("exported")
      assert_equal packaged_skill_files(destination), second.fetch("unchanged")
    end
  end

  def test_skill_export_conflict_is_json_and_does_not_write_other_assets
    Dir.mktmpdir("specproof-cli-") do |directory|
      directory = File.realpath(directory)
      destination = File.join(directory, "client-skills")
      skill_directory = File.join(destination, "specproof-specify")
      FileUtils.mkdir_p(skill_directory)
      existing = File.join(skill_directory, "SKILL.md")
      File.write(existing, "local edits")

      out, err, status = invoke("skills", "export", "--to", destination, "--format", "json")
      assert_equal 2, status.exitstatus
      assert_empty err
      payload = JSON.parse(out)
      assert_equal "skills_export", payload.fetch("kind")
      assert_equal "skills_destination_conflict", payload.fetch("errors").fetch(0).fetch("code")
      assert_equal "local edits", File.read(existing)
      refute File.exist?(File.join(destination, "specproof-test-gaps"))
    end
  end

  private

  def invoke(*)
    Open3.capture3(RbConfig.ruby, "-Ilib", "exe/specproof", *)
  end

  def fixture(name)
    File.expand_path("fixtures/specifications/#{name}", __dir__)
  end

  def packaged_skill_files(destination)
    File.join(File.expand_path("../skills", __dir__), "**", "*")
        .then { |pattern| Dir.glob(pattern, File::FNM_DOTMATCH) }
        .reject { |path| File.directory?(path) || %w[. ..].include?(File.basename(path)) }
        .map do |path|
      File.join(destination,
                path.delete_prefix("#{File.expand_path("../skills", __dir__)}/"))
    end
                      .sort
  end
end
