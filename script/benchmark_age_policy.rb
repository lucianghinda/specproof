#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
gem "minitest", "~> 5.27.0"
require "minitest"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "specproof"

ITERATIONS = Integer(ARGV.fetch(0, "5"))
abort "iterations must be positive" unless ITERATIONS.positive?

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Minitest gem: #{Gem.loaded_specs.fetch("minitest").version}"
puts "Minitest::VERSION: #{Minitest::VERSION}"
puts "SpecProof::VERSION: #{SpecProof::VERSION}"
puts "Iterations per case: #{ITERATIONS}"
puts

# Keep both variants in one generated fixture so their test bodies match.
def runner_source(ages, calls_path, report_path, specification, instrumented)
  test_methods = ages.map do |age|
    <<~TEST
      def test_age_#{age}
        assert_equal #{age >= 18}, @policy.adult?(#{age})
      end
    TEST
  end.join("\n")

  <<~RUBY
    require "bundler/setup"
    gem "minitest", "~> 5.27.0"
    require "minitest"

    $age_policy_call_count = 0
    class AgePolicy
      def adult?(age)
        $age_policy_call_count += 1
        age >= 18
      end
    end

    at_exit { File.write(#{calls_path.dump}, $age_policy_call_count.to_s) }
    require "minitest/autorun"

    if #{instrumented}
      require "specproof/minitest"
      SpecProof::Minitest.install!(
        specifications: [#{specification.dump}],
        output: #{report_path.dump},
        fail_on_missing: false
      )
    end

    class AgePolicyBenchmarkTest < Minitest::Test
      def setup
        @policy = AgePolicy.new
      end

    #{test_methods.lines.map { |line| "  #{line}" }.join}
    end
  RUBY
end

root = File.expand_path("..", __dir__)
specification = File.join(root, "examples/age_policy/specification.rb")
values = {
  3 => [17, 18, 120],
  6 => [0, 1, 17, 18, 119, 120]
}
samples = {}

Dir.mktmpdir("specproof-age-benchmark-") do |directory|
  values.each do |test_count, ages|
    %i[baseline instrumented].each do |mode|
      durations = []
      call_counts = []
      ITERATIONS.times do |iteration|
        runner = File.join(directory, "runner-#{test_count}-#{mode}-#{iteration}.rb")
        calls_path = File.join(directory, "calls-#{test_count}-#{mode}-#{iteration}.txt")
        report_path = File.join(directory, "report-#{test_count}-#{mode}-#{iteration}.json")
        File.write(runner, runner_source(ages, calls_path, report_path, specification, mode == :instrumented))

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        _stdout, stderr, status = Open3.capture3(
          { "RUBYOPT" => nil }, RbConfig.ruby, "-Ilib", runner, chdir: root
        )
        durations << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
        raise "#{mode} #{test_count}-test run failed (#{status.exitstatus}): #{stderr}" unless status.success?

        calls = Integer(File.read(calls_path))
        raise "#{mode} #{test_count}-test run called adult? #{calls} times" unless calls == test_count

        call_counts << calls
        next unless mode == :instrumented

        report = JSON.parse(File.read(report_path))
        hits = report.fetch("obligations").sum { |row| row.fetch("hits") }
        raise "coverage report observed #{hits} calls; expected #{test_count}" unless hits == test_count
      end

      samples[[test_count, mode]] = { durations: durations, calls: call_counts }
    end
  end
end

samples.each do |(test_count, mode), result|
  times = result.fetch(:durations).map { |seconds| format("%.6f", seconds) }
  counts = result.fetch(:calls).uniq
  puts "#{test_count} tests, #{mode}: calls=#{counts.join(",")} wall_seconds=[#{times.join(", ")}]"
end
