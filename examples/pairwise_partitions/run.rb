# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "specproof/minitest"
require_relative "lib/age_policy"

mode = ARGV.shift || "initial"
abort "Choose initial or complete" unless %w[initial complete].include?(mode)

ENV["ADD_MISSING_CATEGORY"] = mode == "complete" ? "1" : "0"
root = File.expand_path("../..", __dir__)
report = File.join(root, "tmp/pairwise-partitions-#{mode}.json")

SpecProof::Minitest.install!(
  specifications: [File.join(__dir__, "specification.rb")],
  criterion: "pairwise-partitions-v1",
  output: report,
  fail_on_missing: false
)

require_relative "test_age_policy"
