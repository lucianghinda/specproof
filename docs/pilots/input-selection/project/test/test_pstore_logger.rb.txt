# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'
require 'fileutils'
require 'time'

class TestPStoreLogger < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @logger = PStoreLogger.new(storage_path: @temp_dir, tag: 'Customer')
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_save_with_timestamp
    data = { id: 1, name: 'John Doe', email: 'john@example.com' }
    filepath = @logger.save(data)

    assert_path_exists filepath
    assert_includes filepath, 'customer'
    assert filepath.end_with?('.pstore')
  end

  def test_save_with_file_id
    data = { id: 1, name: 'John Doe', email: 'john@example.com' }
    filepath = @logger.save(data, file_id: 1)

    assert_path_exists filepath
    assert_includes filepath, '1.pstore'
  end

  def test_save_with_duplicate_file_id
    data1 = { id: 1, name: 'John Doe', email: 'john@example.com' }
    data2 = { id: 1, name: 'Jane Doe', email: 'jane@example.com' }

    filepath1 = @logger.save(data1, file_id: 1)
    filepath2 = @logger.save(data2, file_id: 1)

    assert_path_exists filepath1
    assert_path_exists filepath2
    assert_includes filepath1, '1.pstore'
    assert_includes filepath2, '1_1.pstore'
  end

  def test_load_last
    data1 = { id: 1, name: 'John Doe', email: 'john@example.com' }
    data2 = { id: 2, name: 'Jane Doe', email: 'jane@example.com' }

    @logger.save(data1)
    sleep(0.01) # Ensure different timestamps
    @logger.save(data2)

    loaded_data = @logger.load_last

    assert_equal data2, loaded_data
  end

  def test_load_last_with_no_files
    loaded_data = @logger.load_last

    assert_nil loaded_data
  end

  def test_folder_creation
    expected_path = File.join(@temp_dir, 'orders')
    logger = PStoreLogger.new(storage_path: @temp_dir, tag: 'Orders')

    refute Dir.exist?(expected_path)

    logger.save({ id: 1 })

    assert Dir.exist?(expected_path)
  end

  def test_save_with_timestamp_collision
    data1 = { id: 1, name: 'John Doe', email: 'john@example.com' }
    data2 = { id: 2, name: 'Jane Doe', email: 'jane@example.com' }

    # Mock Time.now to return the same timestamp for both saves
    fixed_time = Time.parse('2025-06-18 10:30:00')
    Time.stub :now, fixed_time do
      filepath1 = @logger.save(data1)
      filepath2 = @logger.save(data2)

      assert_path_exists filepath1
      assert_path_exists filepath2
      assert_includes filepath1, '2025-06-18-10-30-00.pstore'
      assert_includes filepath2, '2025-06-18-10-30-00_1.pstore'
    end
  end
end
