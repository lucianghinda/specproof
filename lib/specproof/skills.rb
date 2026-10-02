# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "tmpdir"

module SpecProof
  # Exports the packaged workflow skills into a client directory.
  module Skills
    SKILL_NAMES = %w[specproof-specify specproof-test-gaps].freeze
    SOURCE_ROOT = File.expand_path("../../skills", __dir__).freeze

    module_function

    # Copies the packaged skills into an explicit client skills directory.
    # `source_root` is an internal seam for tests; production callers use the
    # packaged assets rooted next to this library.
    def export(to:, source_root: SOURCE_ROOT)
      destination = normalized_destination(to)
      assets = packaged_assets(source_root)
      planned = preflight(destination, assets)

      exported = []
      unchanged = []

      planned.each do |asset|
        target = asset.fetch(:target)
        asset.fetch(:files).each do |file|
          output = File.join(target, file.fetch(:relative))
          if file.fetch(:unchanged)
            unchanged << output
            next
          end

          FileUtils.mkdir_p(File.dirname(output))
          write_file(output, file.fetch(:content))
          exported << output
        end
      end

      {
        destination: destination,
        exported: exported.sort,
        unchanged: unchanged.sort
      }
    end

    def normalized_destination(to)
      unless to.is_a?(String) && !to.strip.empty?
        raise configuration_error("An explicit non-empty skill destination is required.", "missing_skills_destination")
      end

      File.expand_path(to)
    end
    private_class_method :normalized_destination

    def packaged_assets(source_root)
      root = File.expand_path(source_root)
      unless File.directory?(root)
        raise configuration_error("Packaged skills directory is missing: #{root}", "invalid_skills_package")
      end

      entries = Dir.children(root).sort
      unless entries == SKILL_NAMES.sort
        raise configuration_error("Packaged skills must contain exactly #{SKILL_NAMES.join(" and ")}.",
                                  "invalid_skills_package")
      end

      SKILL_NAMES.map do |name|
        skill_root = File.join(root, name)
        reject_symlink_path!(skill_root, "skill asset")
        unless File.directory?(skill_root)
          raise configuration_error("Skill asset must be a directory: #{skill_root}", "invalid_skills_package")
        end

        files = Dir.glob(File.join(skill_root, "**", "*"), File::FNM_DOTMATCH).sort.filter_map do |path|
          next if %w[. ..].include?(File.basename(path))

          reject_symlink_path!(path, "skill asset")
          stat = File.lstat(path)
          next if stat.directory?
          unless stat.file?
            raise configuration_error("Skill asset must contain only regular files and directories: #{path}",
                                      "invalid_skills_package")
          end

          relative = path.delete_prefix("#{skill_root}/")
          { relative: relative, content: File.binread(path) }
        end

        unless files.any? { |file| file.fetch(:relative) == "SKILL.md" }
          raise configuration_error("Skill asset is missing SKILL.md: #{skill_root}", "invalid_skills_package")
        end

        { name: name, files: files }
      end
    rescue Errno::ENOENT => e
      raise configuration_error("Packaged skill asset is incomplete: #{e.message}", "invalid_skills_package")
    end
    private_class_method :packaged_assets

    def preflight(destination, assets)
      reject_symlink_path!(destination, "destination")
      if File.exist?(destination) && !File.directory?(destination)
        raise configuration_error("Skill destination must be a directory: #{destination}", "unsafe_skills_destination")
      end

      assets.map do |asset|
        target = File.join(destination, asset.fetch(:name))
        reject_symlink_path!(target, "destination")
        if File.exist?(target) && !File.directory?(target)
          raise configuration_error("Skill destination entry must be a directory: #{target}",
                                    "unsafe_skills_destination")
        end

        unchanged = true
        asset.fetch(:files).each do |file|
          output = File.join(target, file.fetch(:relative))
          reject_symlink_path!(output, "destination")
          next unless File.exist?(output)

          unless File.file?(output)
            raise configuration_error("Skill destination file has an incompatible type: #{output}",
                                      "unsafe_skills_destination")
          end

          unless File.binread(output) == file.fetch(:content)
            raise configuration_error("Skill destination contains different content: #{output}",
                                      "skills_destination_conflict")
          end
        end

        if File.directory?(target)
          Dir.glob(File.join(target, "**", "*"), File::FNM_DOTMATCH).each do |path|
            next if %w[. ..].include?(File.basename(path))

            reject_symlink_path!(path, "destination")
          end
        end

        files = asset.fetch(:files).map do |file|
          output = File.join(target, file.fetch(:relative))
          unchanged = File.file?(output)
          file.merge(unchanged: unchanged)
        end
        { target: target, files: files }
      end
    end
    private_class_method :preflight

    def reject_symlink_path!(path, description)
      expanded = File.expand_path(path)
      current = File::SEPARATOR
      expanded.split(File::SEPARATOR).reject(&:empty?).each do |part|
        current = File.join(current, part)
        next unless File.exist?(current) || File.symlink?(current)

        stat = File.lstat(current)
        if stat.symlink?
          raise configuration_error("Skill #{description} cannot include symlinks: #{current}",
                                    "unsafe_skills_destination")
        end
        if current != expanded && !stat.directory?
          raise configuration_error("Skill #{description} path has a non-directory parent: #{current}",
                                    "unsafe_skills_destination")
        end
      end
    rescue Errno::ENOENT
      nil
    end
    private_class_method :reject_symlink_path!

    def write_file(path, content)
      directory = File.dirname(path)
      Tempfile.create([".specproof-skill-", ".tmp"], directory, binmode: true) do |temporary|
        temporary.write(content)
        temporary.flush
        File.rename(temporary.path, path)
      end
    end
    private_class_method :write_file

    def configuration_error(message, code)
      ConfigurationError.new(message, code: code, path: nil, source: nil)
    end
    private_class_method :configuration_error
  end
end
