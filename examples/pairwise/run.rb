# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "specproof/minitest"

mode = ARGV.shift || "corrected"
output = ARGV.shift || File.expand_path("../../tmp/pairwise-#{mode}.json", __dir__)
implementations = {
  "initial" => ["faulty/lib/delivery_options.rb"],
  "gap" => ["faulty/lib/delivery_options.rb"],
  "corrected" => ["corrected/lib/delivery_options.rb"],
  "three" => ["three_boolean/lib/boolean_batch.rb"]
}.freeze
test_files = {
  "initial" => ["faulty/test/initial_delivery_options_test.rb"],
  "gap" => ["faulty/test/initial_delivery_options_test.rb", "faulty/test/gap_delivery_options_test.rb"],
  "corrected" => ["corrected/test/delivery_options_test.rb"],
  "three" => ["three_boolean/test/boolean_batch_test.rb"]
}.freeze
specifications = {
  "initial" => "specification.rb",
  "gap" => "specification.rb",
  "corrected" => "specification.rb",
  "three" => "three_boolean_specification.rb"
}.freeze
abort "Choose initial, gap, corrected, or three" unless implementations.key?(mode)

require File.join(__dir__, implementations.fetch(mode).first)
SpecProof::Minitest.install!(
  specifications: [File.join(__dir__, specifications.fetch(mode))],
  criterion: "pairwise-finite-v1",
  output: output,
  fail_on_missing: false
)
test_files.fetch(mode).each { |path| require File.join(__dir__, path) }
