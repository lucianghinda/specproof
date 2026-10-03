# frozen_string_literal: true

require 'pstore'
require 'fileutils'

class PStoreLogger
  FILENAME_TIMESTAMP_FORMAT = '%Y-%m-%d-%H-%M-%S'

  def initialize(storage_path:, tag:)
    @storage_path = storage_path
    @tag = tag.downcase
    @folder_path = File.join(@storage_path, @tag)
  end

  def save(data, file_id: nil)
    filepath = file_path(file_id)
    store = PStore.new(filepath)

    store.transaction do
      store[:data] = data
      store[:timestamp] = Time.now
    end

    filepath
  end

  def load_last
    return nil unless Dir.exist?(folder_path)

    files = Dir.glob(File.join(folder_path, '*.pstore'))
    return nil if files.empty?

    latest_file = files.max_by { |file| File.mtime(file) }

    store = PStore.new(latest_file)
    store.transaction(true) do
      store[:data]
    end
  end

  private

    attr_reader :folder_path

    def file_path(file_id)
      FileUtils.mkdir_p(folder_path)
      filename = generate_filename(file_id)

      File.join(folder_path, filename)
    end

    def generate_filename(file_id)
      base_name = file_id.nil? ? Time.now.strftime(FILENAME_TIMESTAMP_FORMAT) : file_id.to_s

      ensure_unique_filename(base_name)
    end

    def ensure_unique_filename(base_name)
      base_filename = "#{base_name}.pstore"
      filepath = File.join(folder_path, base_filename)

      return base_filename unless File.exist?(filepath)

      counter = 1
      loop do
        new_filename = "#{base_name}_#{counter}.pstore"
        new_filepath = File.join(folder_path, new_filename)
        break new_filename unless File.exist?(new_filepath)

        counter += 1
      end
    end
end
