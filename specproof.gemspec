# frozen_string_literal: true

require_relative "lib/specproof/version"

Gem::Specification.new do |spec|
  spec.name = "specproof"
  spec.version = SpecProof::VERSION
  spec.authors = ["Lucian Ghinda"]
  spec.email = ["lucianghinda@users.noreply.github.com"]
  spec.summary = "Check input specifications and measure boundary and finite pairwise coverage."
  spec.description = [
    "SpecProof checks explicit Ruby input domains and partitions,",
    "then plans deterministic boundary and pairwise candidates",
    "without loading application constants."
  ].join(" ")
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = (Dir.glob("{lib,exe,skills,docs,examples,sig}/**/*",
                         File::FNM_DOTMATCH) + %w[README.md LICENSE.txt CHANGELOG.md])
               .select do |path|
    File.file?(path)
  end
    .sort
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |path| File.basename(path) }
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
