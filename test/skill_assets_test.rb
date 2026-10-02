# frozen_string_literal: true

require "test_helper"
require "yaml"

class SkillAssetsTest < Minitest::Test
  EXPECTED_NAMES = %w[specproof-specify specproof-test-gaps].freeze

  def test_packaged_skills_have_matching_frontmatter_and_self_contained_links
    skill_root = File.expand_path("../skills", __dir__)
    assert_equal EXPECTED_NAMES, Dir.children(skill_root).sort

    EXPECTED_NAMES.each do |name|
      root = File.join(skill_root, name)
      skill_file = File.join(root, "SKILL.md")
      assert File.file?(skill_file), "#{name} must include SKILL.md"
      content = File.read(skill_file)
      frontmatter, body = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)\z/m)&.captures
      refute_nil frontmatter, "#{name} must have YAML frontmatter"
      metadata = YAML.safe_load(frontmatter, permitted_classes: [], aliases: false)
      assert_equal name, metadata.fetch("name")
      assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, name)
      assert_operator name.length, :<=, 64
      assert_kind_of String, metadata.fetch("description")
      refute_empty metadata.fetch("description")
      assert_operator metadata.fetch("description").length, :<=, 1024
      refute_match(/\b(?:TODO|TBD|WIP|placeholder)\b|Your code goes here/i, content)

      markdown_files = Dir.glob(File.join(root, "**", "*.md"))
      markdown_files.each do |path|
        File.read(path).scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |href|
          next if href.match?(/\A(?:https?:|mailto:|#)/)

          local_path = href.split("#", 2).first
          resolved = File.expand_path(local_path, File.dirname(path))
          assert resolved.start_with?("#{root}/"), "#{path} links outside its packaged skill: #{href}"
          assert File.file?(resolved),
                 "#{path} links to missing packaged file #{href}"
        end
      end
      refute_empty body
      reference = File.read(File.join(root, "references/usage.md"))
      assert_includes reference, "SpecProof `#{SpecProof::VERSION.split(".").take(2).join(".")}.x`"
      assert_includes reference, "schema `1`"
      assert_includes reference, "input-basics-v1"
    end
  end
end
