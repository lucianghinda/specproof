# frozen_string_literal: true

require_relative "lib/specproof/version"

Gem::Specification.new do |spec|
  spec.name = "specproof"
  spec.version = SpecProof::VERSION
  spec.authors = ["Lucian Ghinda"]
  spec.email = ["lucianghinda@users.noreply.github.com"]
  spec.summary = "Check input specifications and measure boundary and finite pairwise coverage."
  spec.description = [
    "SpecProof is an experimental proof of concept for checking explicit Ruby input domains and partitions,",
    "planning deterministic boundary and pairwise candidates, and observing test coverage.",
    "String targets support offline analysis without loading application code."
  ].join(" ")
  spec.license = "MIT"
  spec.homepage = "https://github.com/lucianghinda/specproof"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir.chdir(__dir__) do
    (Dir.glob(%w[lib/**/*.rb exe/* skills/**/* docs/*.md examples/**/* sig/**/*.rbs]) +
      %w[README.md LICENSE.txt CHANGELOG.md]).select { |path| File.file?(path) }.sort
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |path| File.basename(path) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
end
