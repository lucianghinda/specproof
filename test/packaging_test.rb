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
      assert_includes contents, "exe/specproof"

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
          puts SpecProof::VERSION
        RUBY
        chdir: directory
      )
      assert status.success?, stderr
      assert_equal "#{SpecProof::VERSION}\n", stdout

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
