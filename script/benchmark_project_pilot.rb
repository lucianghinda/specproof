# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "fileutils"

# Compare unchanged focused project tests with and without the optional adapter.
class ProjectPilotBenchmark
  def initialize(directory, iterations)
    @directory = File.expand_path(directory)
    @iterations = Integer(iterations)
    raise ArgumentError, "iterations must be positive" unless @iterations.positive?

    @plan = JSON.parse(File.read(File.join(@directory, "plan.json")))
    @output = File.join(@directory, "runs/benchmark")
    FileUtils.mkdir_p(@output)
  end

  def run
    rows = @iterations.times.flat_map do |index|
      %w[baseline instrumented].map { |mode| measure(mode, index + 1) }
    end
    document = { ruby: RUBY_DESCRIPTION, suite: "original focused config tests", added_tests: false,
                 iterations: @iterations, measurements: rows }
    File.write(File.join(@output, "timings.json"), "#{JSON.pretty_generate(document)}\n")
    puts JSON.pretty_generate(document)
  end

  private

  def measure(mode, iteration)
    prefix = File.join(@output, "#{mode}-#{iteration}")
    environment = {
      "SPECPROOF_ROOT" => File.expand_path("..", __dir__),
      "MT_NO_PLUGINS" => "1",
      "PILOT_PROJECT_ROOT" => File.join(@directory, "project"),
      "PILOT_SPECIFICATION" => File.join(@directory, "config_fetch_spec.rb"),
      "PILOT_REPORT" => "#{prefix}.json",
      "PILOT_ADAPTER" => mode == "instrumented" ? "1" : "0",
      "PILOT_ADDED" => "0"
    }
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "-S", "bundle", "exec", "ruby",
                                            "pilot_runner.rb", "--seed", "12345", chdir: @directory)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    File.write("#{prefix}.stdout", stdout)
    File.write("#{prefix}.stderr", stderr)
    raise "#{mode} suite failed: #{stderr}" unless status.success? && stderr.empty?

    counts = stdout.match(/(\d+) runs, (\d+) assertions, 0 failures, 0 errors, 0 skips/)
    raise "focused suite changed: #{stdout}" unless counts && counts.captures.map(&:to_i) == [45, 342]

    row = { mode: mode, iteration: iteration, wall_seconds: elapsed.round(6), tests: 45, assertions: 342 }
    row.merge!(verify_report("#{prefix}.json")) if mode == "instrumented"
    row
  end

  def verify_report(path)
    report = JSON.parse(File.read(path))
    ids = ->(document) { document.fetch("obligations").map { |row| row.fetch("id") }.sort }
    rows_valid = report.fetch("obligations").all? do |row|
      if row.dig("value", "value") == "files"
        row.fetch("status") == "not_observed" && row.fetch("hits").zero?
      else
        row.fetch("status") == "exercised" && row.fetch("hits").positive?
      end
    end
    valid = report.fetch("completion") == "completed" && report.fetch("integrity") && report.fetch("tests_passed") &&
            report.fetch("contract_digest") == @plan.fetch("contract_digest") && ids.call(report) == ids.call(@plan) &&
            report.fetch("criterion") == "input-basics-v1" && rows_valid && report.fetch("exercised_count") == 7 &&
            report.fetch("missing_count") == 1 && report.fetch("unknown_count").zero? &&
            report.fetch("errors").empty? && report.fetch("outside_domain").empty?
    raise "instrumented evidence changed" unless valid

    { observed_calls: report.fetch("obligations").sum { |row| row.fetch("hits") }, run_id: report.fetch("run_id") }
  end
end

ProjectPilotBenchmark.new(ARGV.fetch(0), ARGV.fetch(1, "5")).run
