# frozen_string_literal: true

require "test_helper"
require "specproof/skills"
require "tmpdir"
require "fileutils"

class SkillsTest < Minitest::Test
  def test_default_export_reads_the_packaged_skill_directories
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      result = SpecProof::Skills.export(to: File.join(tmpdir, "skills"))
      source_root = File.expand_path("../skills", __dir__)
      expected = asset_paths(source_root, File.join(tmpdir, "skills"))

      assert_equal expected, result.fetch(:exported)
      assert_empty result.fetch(:unchanged)
    end
  end

  def test_exports_the_two_skills_to_an_explicit_destination
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      destination = File.join(tmpdir, "client", "skills")

      result = SpecProof::Skills.export(to: destination, source_root: source)

      paths = asset_paths(source, destination)
      assert_equal File.expand_path(destination), result.fetch(:destination)
      assert_equal paths.sort, result.fetch(:exported)
      assert_equal [], result.fetch(:unchanged)
      paths.each { |path| assert File.file?(path) }
    end
  end

  def test_identical_files_are_reported_unchanged_and_other_files_survive
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      destination = File.join(tmpdir, "skills")
      FileUtils.cp_r(source, destination)
      unrelated = File.join(destination, "keep.txt")
      File.write(unrelated, "keep")
      nested_unrelated = File.join(destination, "specproof-specify", "local-notes.md")
      File.write(nested_unrelated, "local notes")

      result = SpecProof::Skills.export(to: destination, source_root: source)

      assert_equal [], result.fetch(:exported)
      expected = asset_paths(source, destination)
      assert_equal expected, result.fetch(:unchanged)
      assert_equal "keep", File.read(unrelated)
      assert_equal "local notes", File.read(nested_unrelated)
    end
  end

  def test_partial_export_keeps_identical_files_unchanged_and_preserves_nested_unrelated_files
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      destination = File.join(tmpdir, "skills")
      first_skill = File.join(destination, "specproof-specify")
      FileUtils.mkdir_p(first_skill)
      copied = File.join(first_skill, "SKILL.md")
      FileUtils.cp(File.join(source, "specproof-specify", "SKILL.md"), copied)
      local_file = File.join(first_skill, "local-notes.md")
      File.write(local_file, "keep this")

      result = SpecProof::Skills.export(to: destination, source_root: source)

      assert_equal [copied], result.fetch(:unchanged)
      refute_includes result.fetch(:exported), copied
      assert_equal "keep this", File.read(local_file)
      assert_includes result.fetch(:exported), File.join(first_skill, "references", "usage.md")
    end
  end

  def test_conflict_preflight_does_not_write_any_assets
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      destination = File.join(tmpdir, "skills")
      FileUtils.mkdir_p(File.join(destination, "specproof-test-gaps"))
      existing = File.join(destination, "specproof-test-gaps", "SKILL.md")
      File.write(existing, "user content")

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination, source_root: source)
      end

      assert_equal "skills_destination_conflict", error.code
      refute File.exist?(File.join(destination, "specproof-specify"))
      assert_equal "user content", File.read(existing)
    end
  end

  def test_rejects_missing_or_blank_destination
    [nil, "", "  "].each do |destination|
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination, source_root: "/unused")
      end
      assert_equal "missing_skills_destination", error.code
    end
  end

  def test_rejects_symlinked_destination_and_asset_path
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      outside = File.join(tmpdir, "outside")
      FileUtils.mkdir_p(outside)
      destination_link = File.join(tmpdir, "linked")
      File.symlink(outside, destination_link)

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination_link, source_root: source)
      end
      assert_equal "unsafe_skills_destination", error.code

      ancestor_link = File.join(tmpdir, "linked-parent")
      File.symlink(outside, ancestor_link)
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: File.join(ancestor_link, "nested", "skills"), source_root: source)
      end
      assert_equal "unsafe_skills_destination", error.code

      destination = File.join(tmpdir, "safe")
      FileUtils.mkdir_p(destination)
      File.symlink(outside, File.join(destination, "specproof-specify"))
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination, source_root: source)
      end
      assert_equal "unsafe_skills_destination", error.code
      assert_empty Dir.children(outside)

      destination = File.join(tmpdir, "file-link")
      FileUtils.mkdir_p(File.join(destination, "specproof-specify"))
      File.symlink(File.join(outside, "target"), File.join(destination, "specproof-specify", "SKILL.md"))
      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination, source_root: source)
      end
      assert_equal "unsafe_skills_destination", error.code
      assert_empty Dir.children(outside)
    end
  end

  def test_existing_non_directory_destination_is_rejected
    Dir.mktmpdir do |tmpdir|
      tmpdir = File.realpath(tmpdir)
      source = fixture_source(tmpdir)
      destination = File.join(tmpdir, "file")
      File.write(destination, "no")

      error = assert_raises(SpecProof::ConfigurationError) do
        SpecProof::Skills.export(to: destination, source_root: source)
      end

      assert_equal "unsafe_skills_destination", error.code
    end
  end

  private

  def asset_paths(source, destination)
    files = Dir.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH)
    files = files.reject { |path| File.directory?(path) || %w[. ..].include?(File.basename(path)) }
    files.map { |path| File.join(destination, path.delete_prefix("#{source}/")) }.sort
  end

  def fixture_source(tmpdir)
    source = File.join(tmpdir, "source")
    %w[specproof-specify specproof-test-gaps].each do |name|
      path = File.join(source, name)
      FileUtils.mkdir_p(File.join(path, "references"))
      File.write(File.join(path, "SKILL.md"), "---\nname: #{name}\ndescription: fixture\n---\n")
      File.write(File.join(path, "references", "usage.md"), "usage for #{name}\n")
    end
    source
  end
end
