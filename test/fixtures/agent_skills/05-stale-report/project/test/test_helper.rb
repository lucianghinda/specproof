# frozen_string_literal: true

require "minitest/autorun"
require "specproof"
require "specproof/minitest"
require_relative "../current"

SpecProof::Minitest.install!(
  specifications: [File.expand_path("../specifications/current.rb", __dir__)],
  output: "tmp/specproof.json",
  fail_on_missing: false
)
