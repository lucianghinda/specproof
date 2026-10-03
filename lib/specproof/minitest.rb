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
      def install!(specifications:, rbs: [], targets: [], output: "tmp/specproof.json", fail_on_missing: false,
                   criterion: "input-basics-v1") # rubocop:disable Metrics/ParameterLists
        ensure_supported_version!
        ensure_not_installed!
        @options = normalized_options(specifications: specifications, rbs: rbs, targets: targets,
                                      output: output, fail_on_missing: fail_on_missing, criterion: criterion)
        @installed = true
        ::Minitest.singleton_class.prepend(RunWrapper)
        self
      end

      private

      def ensure_not_installed!
        return unless @installed

        raise ConfigurationError.new("Minitest adapter is already installed", code: "duplicate_installation")
      end

      def normalized_options(options)
        specifications = options.fetch(:specifications)
        rbs = options.fetch(:rbs)
        targets = options.fetch(:targets)
        output = options.fetch(:output)
        fail_on_missing = options.fetch(:fail_on_missing)
        criterion = options.fetch(:criterion)
        validate_path_options(specifications, rbs, targets)
        validate_output(output)
        validate_criterion(criterion)
        {
          specifications: specifications.map { |path| File.expand_path(path).freeze }.freeze,
          rbs: rbs.map { |path| File.expand_path(path).freeze }.freeze,
          targets: targets.map { |target| target.dup.freeze }.freeze,
          output: File.expand_path(output).freeze,
          criterion: criterion.dup.freeze,
          # Normalize caller truthiness into the boolean report option.
          fail_on_missing: !!fail_on_missing
        }.freeze
      end

      def validate_path_options(specifications, rbs, targets)
        unless specifications.is_a?(Array) && specifications.all?(String)
          raise ConfigurationError.new("specifications must be an array of paths", code: "invalid_specifications")
        end
        unless rbs.is_a?(Array) && rbs.all?(String)
          raise ConfigurationError.new("rbs must be an array of paths", code: "invalid_rbs")
        end
        unless targets.is_a?(Array) && targets.all?(String)
          raise ConfigurationError.new("targets must be an array of target names", code: "invalid_targets")
        end

        if rbs.empty? && targets.empty?
          unless specifications.any?
            raise ConfigurationError.new("specifications must be a non-empty array of paths",
                                         code: "invalid_specifications")
          end
        elsif rbs.empty?
          raise ConfigurationError.new("RBS targets require at least one RBS file", code: "rbs_without_paths")
        elsif targets.empty?
          raise ConfigurationError.new("RBS files require at least one selected target", code: "targets_required")
        end
      end

      def validate_output(output)
        return if output.is_a?(String) && !output.empty?

        raise ConfigurationError.new("output must be a non-empty path", code: "invalid_output")
      end

      def validate_criterion(criterion)
        return if criterion.is_a?(String) && !criterion.empty?

        raise ConfigurationError.new("criterion must be a non-empty string", code: "invalid_criterion")
      end

      public

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

    # Builds honest source-input metadata for the current invocation.
    module ReportScope
      def self.declaration_sources(options)
        canonical_paths = lambda do |paths|
          paths.map do |path|
            File.realpath(path)
          rescue SystemCallError
            File.expand_path(path)
          end.uniq.sort.freeze
        end
        {
          specifications: canonical_paths.call(options.fetch(:specifications)),
          rbs: canonical_paths.call(options.fetch(:rbs)),
          targets: options.fetch(:targets).uniq.sort.freeze
        }.freeze
      end

      def self.pattern_value(arguments, short, long)
        pattern = nil
        arguments.each_with_index do |argument, index|
          if [short, long].include?(argument)
            pattern = arguments[index + 1]
          elsif argument.start_with?("#{long}=")
            pattern = argument.delete_prefix("#{long}=")
          elsif argument.start_with?(short) && argument.length > short.length
            pattern = argument.delete_prefix(short)
          end
        end
        pattern
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
        @declaration_sources = ReportScope.declaration_sources(@options)
        @criterion = @options.fetch(:criterion)
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
        @specifications = SpecProof.load(@options.fetch(:specifications), rbs: @options.fetch(:rbs),
                                                                          targets: @options.fetch(:targets))
        @obligations = SpecProof.plan(@specifications, criterion: @criterion)
        @coverage = Coverage.new(obligations: @obligations, specifications: @specifications)
        projection = @coverage.to_report
        @contract_digest = Report.digest(@specifications)

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
        finding = e.respond_to?(:findings) ? e.findings.first : nil
        source = e.respond_to?(:source) ? e.source : finding&.sources&.first
        add_error(error_code(e), safe_error(e), target: finding&.target,
                                                path: e.respond_to?(:path) ? e.path : nil,
                                                source: source)
        mark_all_incomplete("coverage analysis could not start")
        @contract_digest ||= ""
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
            declaration_sources: @declaration_sources,
            arguments: @args,
            filter: ReportScope.pattern_value(@args, "-n", "--name"),
            exclude: ReportScope.pattern_value(@args, "-e", "--exclude")
          }.merge(Report.input_scope(@specifications)),
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
          if item.key?(:inputs)
            values = item.fetch(:inputs).map { |name, value| "#{name}=#{human_value(value)}" }.join(",")
            "#{item.fetch(:target)}/#{values}"
          else
            "#{item.fetch(:target)}/#{item.fetch(:input)}=#{human_value(item.fetch(:value))}"
          end
        end
        if missing_values.any?
          remaining = projection.fetch(:missing_count) - missing_values.length
          missing_values << "… +#{remaining} more" if remaining.positive?
          text += "; missing values: #{missing_values.join(", ")}"
        end
        text += "; completeness scope: analyzed inputs only"
        text += "; #{projection.fetch(:excluded_pairs).length} excluded pairs" if projection.key?(:excluded_pairs)
        text += pairwise_summary
        exclusions = @specifications.flat_map do |specification|
          specification.exclusions.values.map do |item|
            "#{specification.target}/#{item.name} (#{item.reason})"
          end
        end
        text += "; excluded: #{exclusions.join(", ")}" unless exclusions.empty?
        text += " (#{completion})"
        $stdout.puts(text)
      end

      def pairwise_summary
        return "" unless @criterion == "pairwise-finite-v1"

        groups = @specifications.filter_map do |specification|
          group = specification.respond_to?(:combination_group) && specification.combination_group
          "#{specification.target}(#{group.inputs.join(", ")})" if group
        end
        "; criterion: #{@criterion}; group: #{groups.join("; ")}"
      end

      def human_value(value)
        case value[:kind]
        when "nil" then "nil"
        when "boolean" then value[:value] ? "true" : "false"
        when "integer" then value[:value]
        when "symbol" then ":#{value[:value]}"
        when "string" then value[:value].inspect
        else "?"
        end
      end

      def add_error(code, message, target: nil, path: nil, source: nil)
        return if @errors.length >= ERROR_LIMIT

        error = { code: code.to_s, message: safe_string(message) }
        error[:target] = safe_string(target) if target
        error[:path] = safe_string(path) if path
        error[:source] = source.to_h if source.respond_to?(:to_h)
        @errors << error unless @errors.include?(error)
      end

      def error_code(error)
        if error.respond_to?(:code)
          error.code.to_s
        elsif error.respond_to?(:findings) && (finding = error.findings.first)
          finding.code.to_s
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
