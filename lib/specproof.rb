# frozen_string_literal: true

require_relative "specproof/version"
require_relative "specproof/model"
require_relative "specproof/domains"
require_relative "specproof/type_constraints"
require_relative "specproof/combinations"
require_relative "specproof/loader"
require_relative "specproof/composer"
require_relative "specproof/checker"
require_relative "specproof/planner"
require_relative "specproof/report"
require_relative "specproof/coverage_report"
require_relative "specproof/suggestions"

# Checks Ruby input-domain specifications and plans deterministic candidates.
module SpecProof
  class Error < StandardError; end

  # Reports invalid options and declarations with stable machine-readable codes.
  class ConfigurationError < Error
    attr_reader :code, :source, :path

    def initialize(message, code: "configuration_error", source: nil, path: nil)
      super(message)
      @code = code.to_s.freeze
      @source = source
      @path = path&.to_s&.freeze
    end
  end

  # Reports contradictions found in otherwise well-formed specifications.
  class InvalidSpecificationError < Error
    attr_reader :findings

    def initialize(findings)
      @findings = findings.freeze
      super("specifications contain semantic findings")
    end
  end

  def self.load(paths, rbs: [], targets: [])
    rbs_paths = Array(rbs)
    selected_targets = Array(targets)
    return Loader.load(paths) if rbs_paths.empty? && selected_targets.empty?
    if rbs_paths.empty?
      raise ConfigurationError.new("RBS targets require at least one RBS file", code: "rbs_without_paths")
    end
    if selected_targets.empty?
      raise ConfigurationError.new("RBS files require at least one selected target", code: "targets_required")
    end

    require_relative "specproof/sources/rbs"
    dsl_paths = normalize_mixed_paths(paths, rbs_paths)
    specifications = dsl_paths.empty? ? [] : Loader.load(dsl_paths, allow_exclusion_only: true)
    declarations = specifications.to_h { |specification| [specification.target, specification] }
    type_facts = Sources::RBS.load(paths: rbs_paths, targets: selected_targets, declarations: declarations)
    Composer.compose(specifications: specifications, type_facts: type_facts)
  end

  def self.normalize_mixed_paths(paths, rbs_paths)
    dsl_paths = Array(paths).map { |path| canonical_path(path) }
    canonical = dsl_paths + rbs_paths.map { |path| canonical_path(path) }
    if canonical.uniq.length != canonical.length
      raise ConfigurationError.new("supplied specification and RBS paths must be unique", code: "duplicate_path")
    end

    dsl_paths.sort.freeze
  end
  private_class_method :normalize_mixed_paths

  def self.canonical_path(value)
    path = File.path(value)
    File.realpath(path)
  rescue Errno::ENOENT, Errno::EACCES => e
    raise ConfigurationError.new(e.message, code: "file_not_found", path: e.respond_to?(:path) ? e.path : path)
  rescue SystemCallError, TypeError, ArgumentError => e
    raise ConfigurationError.new(e.message, code: "file_error", path: e.respond_to?(:path) ? e.path : path)
  end
  private_class_method :canonical_path

  def self.check(specifications)
    Checker.new(specifications).findings
  end

  def self.plan(specifications, criterion: "input-basics-v1")
    Planner.new(specifications, criterion: criterion).obligations
  end

  def self.suggest(specifications, report:)
    Suggestions.new(specifications, report: report).result
  end
end

require_relative "specproof/coverage"
require_relative "specproof/skills"

Specproof = SpecProof unless Object.const_defined?(:Specproof, false)
