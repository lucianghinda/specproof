# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "specproof/minitest"

mode = ARGV.shift || "correct"
output = ARGV.shift || File.expand_path("../../tmp/age-policy-#{mode}.json", __dir__)
tests = {
  "correct" => "test/age_policy_test.rb",
  "missing" => "faulty/test/age_policy_examples_test.rb",
  "regression" => "faulty/test/age_policy_test.rb"
}.freeze
abort "Choose correct, missing, or regression" unless tests.key?(mode)

implementation = mode == "correct" ? "lib/age_policy.rb" : "faulty/lib/age_policy.rb"
require File.join(__dir__, implementation)
SpecProof::Minitest.install!(
  specifications: [File.join(__dir__, "specification.rb")],
  output: output,
  fail_on_missing: ENV["SPECPROOF_STRICT"] == "1"
)
require File.join(__dir__, tests.fetch(mode))
