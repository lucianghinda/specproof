# frozen_string_literal: true

require "test_helper"
require "json"
require "rubygems/package"
require "rubygems/installer"
require "open3"
require "rbconfig"
require "tmpdir"

class PackagingTest < Minitest::Test
  # Building and installing a real gem is intentionally one end-to-end check.
  def test_built_gem_installs_and_loads_outside_the_checkout_without_minitest
    Dir.mktmpdir("specproof-package-", "/private/tmp") do |directory|
      gem_home = File.join(directory, "gem-home")
      package_path = File.join(directory, "specproof.gem")
      specification = Gem::Specification.load(File.expand_path("../specproof.gemspec", __dir__))
      Gem::Package.build(specification, true, false, package_path)

      package = Gem::Package.new(package_path)
      assert_empty package.spec.runtime_dependencies
      contents = package.contents
      assert_includes contents, "lib/specproof.rb"
      assert_includes contents, "skills/specproof-specify/SKILL.md"
      assert_includes contents, "skills/specproof-test-gaps/SKILL.md"
      assert_includes contents, "examples/rbs_registration/sig/registration.rbs"
      assert_includes contents, "examples/rbs_registration/requirements.md"
      assert_includes contents, "exe/specproof"
      assert_includes contents, "docs/report-format.md"
      assert_includes contents, "sig/specproof.rbs"
      refute contents.any? { |path| path.match?(%r{\Adocs/(pilots|evaluations|superpowers)/}) },
             "internal release evidence and workspaces must not ship in the gem"
      refute(contents.any? { |path| path.end_with?(".tar.gz", ".jsonl") })
      assert_equal "https://github.com/lucianghinda/specproof", package.spec.homepage
      assert_equal "https://github.com/lucianghinda/specproof/blob/main/CHANGELOG.md",
                   package.spec.metadata.fetch("changelog_uri")

      Gem::Installer.at(package_path, install_dir: gem_home, wrappers: true, force: true).install
      environment = {
        "GEM_HOME" => gem_home,
        "GEM_PATH" => gem_home,
        "RUBYOPT" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLER_VERSION" => nil
      }
      stdout, stderr, status = Open3.capture3(
        environment,
        RbConfig.ruby, "-e", <<~RUBY,
          gem "specproof"
          require "specproof"
          abort "SpecProof unexpectedly loaded Minitest" if defined?(Minitest)
          abort "SpecProof unexpectedly loaded optional RBS" if defined?(::RBS)
          puts SpecProof::VERSION
        RUBY
        chdir: directory
      )
      assert status.success?, stderr
      assert_equal "#{SpecProof::VERSION}\n", stdout

      specification = File.expand_path("../examples/age_policy/specification.rb", __dir__)
      check, check_error, check_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"),
        "check", specification, "--format", "json", chdir: directory
      )
      assert check_status.success?, check_error
      assert_equal "check", JSON.parse(check).fetch("kind")

      plan, plan_error, plan_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"),
        "plan", specification, "--format", "json", chdir: directory
      )
      assert plan_status.success?, plan_error
      assert_equal "plan", JSON.parse(plan).fetch("kind")

      cli, cli_error, cli_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"), "--version", chdir: directory
      )
      assert cli_status.success?, cli_error
      assert_equal "SpecProof #{SpecProof::VERSION}\n", cli

      destination = File.join(directory, "client skills")
      cli, cli_error, cli_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"),
        "skills", "export", "--to", destination, chdir: directory
      )
      assert cli_status.success?, cli_error
      owned_skill = File.join(destination, "specproof-specify/SKILL.md")
      assert File.file?(owned_skill), cli
      original_content = File.read(owned_skill)
      refute_empty original_content

      cli, cli_error, cli_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"),
        "skills", "export", "--to", destination, "--format", "json", chdir: directory
      )
      assert cli_status.success?, cli_error
      assert_equal %w[specproof-specify/SKILL.md specproof-specify/references/usage.md
                      specproof-test-gaps/SKILL.md specproof-test-gaps/references/usage.md]
        .map { |path| File.join(destination, path) },
                   JSON.parse(cli).fetch("unchanged")

      File.write(owned_skill, "client-owned edit\n")
      cli, cli_error, cli_status = Open3.capture3(
        environment, RbConfig.ruby, File.join(gem_home, "bin/specproof"),
        "skills", "export", "--to", destination, "--format", "json", chdir: directory
      )
      assert_equal 2, cli_status.exitstatus, cli_error
      assert_equal "client-owned edit\n", File.read(owned_skill)
      assert_equal "skills_export", JSON.parse(cli).fetch("kind")
    end
  end
end
