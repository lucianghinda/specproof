# frozen_string_literal: true

require "pathname"
require_relative "../../specproof"
require_relative "rbs_projector"

module SpecProof
  module Sources
    # Reads the deliberately small, explicit RBS subset used for scalar input facts.
    module RBS
      VERSION = "4.2.0"

      class << self
        def load(paths:, targets:, declarations: {})
          canonical_paths = normalize_paths(paths)
          targets = normalize_targets(targets)
          rbs = load_dependency
          verify_version!(rbs)

          buffers = canonical_paths.map { |path| parse(path, rbs) }
          environment = resolve_environment(buffers, rbs)
          facts = targets.flat_map do |target|
            RBSProjector.new(target, environment, canonical_paths, rbs,
                             declaration: declarations[target]).facts
          end
          facts.sort_by { |fact| [fact.target, fact.input.to_s] }.freeze
        end

        private

        def normalize_paths(paths)
          values = Array(paths)
          if values.empty?
            raise ConfigurationError.new("provide at least one RBS signature file", code: "paths_required")
          end

          canonical = values.map do |entry|
            input_path = nil
            input_path = File.path(entry)
            path = File.realpath(input_path)
            unless File.file?(path)
              raise ConfigurationError.new(
                "RBS signature path is not a regular file: #{path}", code: "file_error", path: path
              )
            end
            path
          rescue Errno::ENOENT => e
            raise ConfigurationError.new(e.message, code: "file_not_found",
                                                    path: e.respond_to?(:path) ? e.path : input_path)
          rescue SystemCallError => e
            raise ConfigurationError.new(e.message, code: "file_error",
                                                    path: e.respond_to?(:path) ? e.path : input_path)
          rescue TypeError, ArgumentError => e
            raise ConfigurationError.new(e.message, code: "file_error", path: input_path)
          end
          if canonical.uniq.length != canonical.length
            raise ConfigurationError.new("RBS signature paths must be unique", code: "duplicate_path")
          end

          canonical.sort.freeze
        end

        def normalize_targets(targets)
          values = Array(targets)
          raise ConfigurationError.new("provide at least one RBS target", code: "targets_required") if values.empty?

          values.each do |target|
            unless Loader.valid_target?(target)
              raise ConfigurationError.new("target must use ClassName#instance_method syntax: #{target.inspect}",
                                           code: "invalid_target")
            end
          end
          if values.uniq.length != values.length
            raise ConfigurationError.new("RBS targets must be unique", code: "duplicate_target")
          end

          values.sort.freeze
        end

        def load_dependency
          require "rbs"
          ::RBS
        rescue LoadError => e
          raise ConfigurationError.new("RBS support requires the optional rbs gem (4.2.0): #{e.message}",
                                       code: "rbs_dependency_missing")
        end

        def verify_version!(rbs)
          return if rbs::VERSION == VERSION

          raise ConfigurationError.new("RBS #{VERSION} is required; found #{rbs::VERSION}",
                                       code: "unsupported_rbs_version")
        end

        def parse(path, rbs)
          buffer = rbs::Buffer.new(name: Pathname(path), content: File.read(path))
          buffer, directives, declarations = rbs::Parser.parse_signature(buffer)
          [buffer, directives, declarations].freeze
        rescue rbs::ParsingError => e
          source = Source.new(path: path, line: e.location.start_line, kind: "rbs") if e.location
          raise ConfigurationError.new(e.message, code: "rbs_parse_error", path: path, source: source)
        rescue Errno::ENOENT, Errno::EACCES => e
          raise ConfigurationError.new(e.message, code: "file_error", path: path)
        end

        def resolve_environment(buffers, rbs)
          environment = rbs::Environment.from_loader(rbs::EnvironmentLoader.new)
          buffers.each do |buffer, directives, declarations|
            environment.add_source(rbs::Source::RBS.new(buffer, directives, declarations))
          end
          environment.resolve_type_names
        rescue rbs::BaseError => e
          location = e.respond_to?(:location) ? e.location : nil
          buffer = location&.buffer
          path = buffer.name.to_s if buffer
          source = Source.new(path: path, line: location.start_line, kind: "rbs") if location && path
          raise ConfigurationError.new(e.message, code: "rbs_parse_error", path: path, source: source)
        end
      end
    end
  end
end
