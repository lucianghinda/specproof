# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |task|
  task.test_globs = ["test/test_*.rb", "test/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new do |task|
  task.options = ["--cache-root", File.join(__dir__, "tmp/rubocop"), "--no-parallel"]
end

task default: %i[test rubocop]
