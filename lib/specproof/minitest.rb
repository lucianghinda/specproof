# frozen_string_literal: true

require "json"
require "fileutils"
require "securerandom"
require "tempfile"
require "minitest"
require "specproof"
require_relative "coverage"
require_relative "collector"

# Records Minitest run coverage against the declared input obligations.
module SpecProof
  # Integrates contract coverage with a Minitest run lifecycle.
  module Minitest
    MIN_SUPPORTED_MINITEST_VERSION = Gem::Version.new("5.26.2")

    class << self
      def install!(specifications:, output: "tmp/specproof.json", fail_on_missing: false)
        ensure_supported_version!
        if @installed
          raise ConfigurationError.new("Minitest adapter is already installed",
                                       code: "duplicate_installation")
        end
        unless specifications.is_a?(Array) && !specifications.empty? && specifications.all?(String)
          raise ConfigurationError.new("specifications must be a non-empty array of paths",
                                       code: "invalid_specifications")
        end
        unless output.is_a?(String) && !output.empty?
          raise ConfigurationError.new("output must be a non-empty path", code: "invalid_output")
        end

        @installed = true
        @options = {
          specifications: specifications.map { |path| File.expand_path(path).freeze }.freeze,
          output: File.expand_path(output).freeze,
          # Normalize caller truthiness into the boolean report option.
          fail_on_missing: !!fail_on_missing # rubocop:disable Style/DoubleNegation
        }.freeze
        ::Minitest.singleton_class.prepend(RunWrapper)
        self
      end

      def ensure_supported_version!
        package_version = Gem.loaded_specs.fetch("minitest", nil)&.version
        runtime_version = Gem::Version.new(::Minitest::VERSION)
        max_version = Gem::Version.new("5.28.0")
        supported_package = !package_version ||
                            (package_version >= MIN_SUPPORTED_MINITEST_VERSION && package_version < max_version)
        supported_runtime = runtime_version >= MIN_SUPPORTED_MINITEST_VERSION && runtime_version < max_version
        versions_match = !package_version || package_version.segments.take(2) == runtime_version.segments.take(2)
        return if supported_package && supported_runtime && versions_match

        message = "Minitest adapter supports Minitest >= 5.26.2 and < 5.28.0 " \
                  "(loaded package #{package_version || "unknown"}, runtime #{runtime_version})"
        raise ConfigurationError.new(
          message,
          code: "unsupported_minitest_version"
        )
      end

      def run(args, &)
        run = Run.new(@options, args)
        run.execute(&)
      end
    end

    # Wraps Minitest's run entry point only while the adapter is installed.
    module RunWrapper
      def run(*args, **kwargs, &block)
        return super unless SpecProof::Minitest.instance_variable_get(:@installed)

        SpecProof::Minitest.run(args) { super(*args, **kwargs, &block) }
      end
    end

    # Owns the preparation, collection, and finalization phases for one run.
    class Run
      ERROR_LIMIT = 20

      def initialize(options, args)
        @options = options
        @args = args.flatten.grep(String).map { |item| safe_string(item) }
        @run_id = SecureRandom.uuid
        @errors = []
        @specifications = []
        @obligations = []
        @coverage = nil
        @collector = nil
        @integrity_ok = true
        @marker_written = false
      end

      def execute
        prepare
        result = nil
        original_exception = nil
        begin
          result = yield
        # Re-raise SystemExit and Interrupt after writing the final report.
        rescue Exception => e # rubocop:disable Lint/RescueException
          original_exception = e
          @integrity_ok = false
          mark_all_incomplete("Minitest runner raised before completing")
          add_error("runner_failed", safe_error(e))
        ensure
          if result.nil?
            @integrity_ok = false
            mark_all_incomplete("Minitest runner did not complete")
            add_error("runner_incomplete", "Minitest returned without a completed result") unless original_exception
          end
          finalize(result)
        end

        raise original_exception if original_exception

        no_missing = @coverage.nil? || @coverage.to_report.fetch(:missing_count).zero?
        return false unless @integrity_ok
        return false if @options.fetch(:fail_on_missing) && !no_missing

        result
      end

      private

      def prepare
        @specifications = SpecProof.load(@options.fetch(:specifications))
        @obligations = SpecProof.plan(@specifications)
        @coverage = Coverage.new(obligations: @obligations, specifications: @specifications)
        projection = @coverage.to_report
        @contract_digest = Report.digest(@specifications)
        @criterion = "input-basics-v1"

        if parallel_suites?
          @integrity_ok = false
          add_error("parallel_suite", "coverage collection does not support parallel Minitest suites")
          mark_all_incomplete("parallel suite could not be collected")
        else
          @collector = Collector.new(specifications: @specifications, observer: @coverage)
        end

        @marker_written = atomic_write(running_report(projection))
        if @marker_written && @collector
          begin
            @collector.start
          rescue StandardError => e
            @integrity_ok = false
            add_error(error_code(e), safe_error(e))
            mark_all_incomplete("collector could not start")
          end
        elsif !@marker_written
          @integrity_ok = false
          add_error("report_write_failed", "could not write running coverage marker")
          mark_all_incomplete("coverage report could not be written")
        end
      rescue StandardError => e
        @integrity_ok = false
        add_error(error_code(e), safe_error(e))
        mark_all_incomplete("coverage analysis could not start")
        @contract_digest ||= ""
        @criterion ||= "input-basics-v1"
        @marker_written ||= atomic_write(running_report(@coverage&.to_report || empty_projection))
      end

      def finalize(result)
        begin
          @collector&.stop
        rescue StandardError => e
          @integrity_ok = false
          add_error("collector_stop_failed", safe_error(e))
          mark_all_incomplete("collector could not stop cleanly")
        end
        collect_issues

        tests_passed = result.nil? ? nil : result != false
        projection = @coverage&.to_report || empty_projection
        completion = if !@integrity_ok || projection.fetch(:completeness) == "incomplete"
                       "incomplete"
                     else
                       "completed"
                     end
        final_report = report(projection).merge(
          completion: completion,
          integrity: @integrity_ok,
          tests_passed: tests_passed
        )
        unless @marker_written && atomic_write(final_report)
          @integrity_ok = false
          add_error("report_write_failed", "could not write final coverage report")
          warn("SpecProof coverage report failed (run #{@run_id}): final report could not be written")
          return
        end

        print_summary(projection, completion)
      rescue StandardError => e
        @integrity_ok = false
        add_error("reporting_failed", safe_error(e))
        warn("SpecProof coverage report failed (run #{@run_id}): #{safe_error(e)}")
      end

      def collect_issues
        Array(@collector&.issues).each do |issue|
          @coverage&.mark_incomplete(target: issue[:target], reason: issue[:message])
          @integrity_ok = false
          add_error(issue[:code], issue[:message], target: issue[:target])
        end
      end

      def mark_all_incomplete(reason)
        @specifications.each do |specification|
          @coverage&.mark_incomplete(target: specification.target, reason: reason)
        end
      end

      def parallel_suites?
        ::Minitest::Runnable.runnables.any? do |suite|
          suite.respond_to?(:test_order) && suite.test_order == :parallel
        end
      end

      def running_report(projection)
        report(projection).merge(completion: "running", integrity: false, tests_passed: nil)
      end

      def report(projection)
        Report.envelope(kind: "coverage", errors: @errors.dup).merge(
          contract_digest: @contract_digest || "",
          criterion: @criterion || "input-basics-v1",
          run_id: @run_id,
          scope: {
            ruby_engine: RUBY_ENGINE,
            pid: Process.pid,
            thread: Thread.current.object_id,
            window: "minitest_run",
            method_identity: "direct_owner_definition",
            input_semantics: "effective_bound_values",
            argument_presence: "not_observed",
            targets: @specifications.map(&:target).sort,
            arguments: @args,
            filter: pattern_value("-n", "--name"),
            exclude: pattern_value("-e", "--exclude")
          },
          evidence_mode: "obligation_hits",
          replay: false
        ).merge(projection.except(:status, :completeness))
      end

      def empty_projection
        { obligations: [], missing: [], exercised: [], exercised_count: 0, obligation_count: 0,
          missing_count: 0, unknown_count: 0, not_observed_count: 0, completion_percent: nil,
          outside_domain: {}, incomplete_reasons: [], evidence_mode: "obligation_hits", replay: false }
      end

      def atomic_write(document)
        output = @options.fetch(:output)
        directory = File.dirname(output)
        FileUtils.mkdir_p(directory)
        Tempfile.create([".specproof-", ".json"], directory) do |file|
          file.write(JSON.pretty_generate(document))
          file.write("\n")
          file.flush
          file.fsync
          File.rename(file.path, output)
        end
        true
      rescue StandardError => e
        add_error("report_write_failed", safe_error(e))
        false
      end

      def print_summary(projection, completion)
        text = "SpecProof coverage run #{@run_id}: " \
               "#{projection.fetch(:exercised_count)}/#{projection.fetch(:obligation_count)} obligations exercised"
        text += ", #{projection.fetch(:missing_count)} missing" if projection.fetch(:missing_count).positive?
        text += ", #{projection.fetch(:unknown_count)} unknown" if projection.fetch(:unknown_count).positive?
        missing_values = projection.fetch(:missing).first(10).map do |item|
          "#{item.fetch(:target)}/#{item.fetch(:input)}=#{human_value(item.fetch(:value))}"
        end
        if missing_values.any?
          remaining = projection.fetch(:missing_count) - missing_values.length
          missing_values << "… +#{remaining} more" if remaining.positive?
          text += "; missing values: #{missing_values.join(", ")}"
        end
        text += " (#{completion})"
        $stdout.puts(text)
      end

      def human_value(value)
        case value[:kind]
        when "nil" then "nil"
        when "boolean" then value[:value] ? "true" : "false"
        when "integer" then value[:value]
        when "symbol" then ":#{value[:value]}"
        else "?"
        end
      end

      def add_error(code, message, target: nil)
        return if @errors.length >= ERROR_LIMIT

        error = { code: code.to_s, message: safe_string(message) }
        error[:target] = safe_string(target) if target
        @errors << error unless @errors.include?(error)
      end

      def pattern_value(short, long)
        pattern = nil
        @args.each_with_index do |argument, index|
          if [short, long].include?(argument)
            pattern = @args[index + 1]
          elsif argument.start_with?("#{long}=")
            pattern = argument.delete_prefix("#{long}=")
          elsif argument.start_with?(short) && argument.length > short.length
            pattern = argument.delete_prefix(short)
          end
        end
        pattern
      end

      def error_code(error)
        if error.respond_to?(:code)
          error.code.to_s
        else
          error.class.name.split("::").last.gsub(/([a-z])([A-Z])/,
                                                 "\\1_\\2").downcase
        end
      end

      def safe_error(error)
        safe_string(error.message.to_s.empty? ? error.class.name : error.message)
      end

      def safe_string(value)
        value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?").byteslice(0, 240).to_s
      end
    end
  end
end
