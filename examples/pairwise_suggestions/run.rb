# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "specproof/minitest"

mode = ARGV.shift || "delivery-corrected"
output = ARGV.shift || File.expand_path("../../tmp/pairwise-suggestions-#{mode}.json", __dir__)

pairwise_root = File.expand_path("../pairwise", __dir__)
scenarios = {
  "delivery-baseline" => {
    implementation: "faulty/lib/delivery_options.rb",
    specification: "specification.rb",
    tests: ["faulty/test/initial_delivery_options_test.rb"]
  },
  "delivery-gap" => {
    implementation: "faulty/lib/delivery_options.rb",
    specification: "specification.rb",
    tests: [
      "faulty/test/initial_delivery_options_test.rb",
      "faulty/test/gap_delivery_options_test.rb"
    ]
  },
  "delivery-corrected" => {
    implementation: "corrected/lib/delivery_options.rb",
    specification: "specification.rb",
    tests: ["corrected/test/delivery_options_test.rb"]
  },
  "booleans-baseline" => {
    implementation: "pairwise_suggestions/three_boolean/lib/suggested_boolean_batch.rb",
    specification: "pairwise_suggestions/three_boolean/specification.rb",
    tests: ["pairwise_suggestions/three_boolean/test/baseline_test.rb"]
  },
  "booleans-complete" => {
    implementation: "pairwise_suggestions/three_boolean/lib/suggested_boolean_batch.rb",
    specification: "pairwise_suggestions/three_boolean/specification.rb",
    tests: ["pairwise_suggestions/three_boolean/test/complete_test.rb"]
  }
}.freeze

abort "Choose one of: #{scenarios.keys.join(", ")}" unless scenarios.key?(mode)

scenario = scenarios.fetch(mode)
root = mode.start_with?("delivery-") ? pairwise_root : File.expand_path("..", __dir__)
require File.join(root, scenario.fetch(:implementation))

SpecProof::Minitest.install!(
  specifications: [File.join(root, scenario.fetch(:specification))],
  criterion: "pairwise-finite-v1",
  output: output,
  fail_on_missing: false
)

scenario.fetch(:tests).each { |path| require File.join(root, path) }
