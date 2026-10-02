# frozen_string_literal: true

require_relative "specproof/version"
require_relative "specproof/model"
require_relative "specproof/domains"
require_relative "specproof/type_constraints"
require_relative "specproof/loader"
require_relative "specproof/composer"
require_relative "specproof/checker"
require_relative "specproof/planner"
require_relative "specproof/report"

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

  def self.load(paths)
    Loader.load(paths)
  end

  def self.check(specifications)
    Checker.new(specifications).findings
  end

  def self.plan(specifications, criterion: "input-basics-v1")
    Planner.new(specifications, criterion: criterion).obligations
  end
end

require_relative "specproof/coverage"
require_relative "specproof/skills"

Specproof = SpecProof unless Object.const_defined?(:Specproof, false)
