# frozen_string_literal: true

require 'pathname'
require_relative 'test_case'
require_relative '../../lib/wavesync/file_sync_throttle'

module Wavesync
  class FileSyncThrottleTest < Wavesync::TestCase
    def setup
      @tmpdir = Dir.mktmpdir
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    test 'default mode is file_size' do
      throttle = FileSyncThrottle.new
      assert_equal :file_size, throttle.mode
    end

    test 'mode can be set at construction' do
      throttle = FileSyncThrottle.new(mode: :disk_space)
      assert_equal :disk_space, throttle.mode
    end

    test 'file_size: wait_for_sync returns immediately when file size is stable on first poll' do
      throttle = FileSyncThrottle.new(mode: :file_size)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      throttle.wait_for_sync(target_path)
    end

    test 'file_size: wait_for_sync polls until size is stable' do
      throttle = FileSyncThrottle.new(mode: :file_size)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio')

      sizes = [5, 10, 10]
      File.stubs(:size).with(target_path.to_s).returns(*sizes)
      throttle.stubs(:wait)

      throttle.wait_for_sync(target_path)
    end

    test 'file_size: wait_for_sync returns immediately when file does not exist' do
      throttle = FileSyncThrottle.new(mode: :file_size)
      target_path = Pathname.new(File.join(@tmpdir, 'missing.wav'))

      throttle.wait_for_sync(target_path)
    end

    test 'disk_space: wait_for_sync returns when free space exceeds threshold' do
      throttle = FileSyncThrottle.new(mode: :disk_space)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      free_space_sequence = [100 * 1024 * 1024, 600 * 1024 * 1024]
      throttle.stubs(:free_space_bytes).returns(*free_space_sequence)
      throttle.stubs(:wait)

      throttle.wait_for_sync(target_path)
    end

    test 'disk_space: wait_for_sync returns immediately when free space already sufficient' do
      throttle = FileSyncThrottle.new(mode: :disk_space)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      throttle.stubs(:free_space_bytes).returns(600 * 1024 * 1024)
      throttle.expects(:wait).never

      throttle.wait_for_sync(target_path)
    end

    test 'fixed_delay: wait_for_sync waits for the fixed delay' do
      throttle = FileSyncThrottle.new(mode: :fixed_delay)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      throttle.expects(:wait).with(FileSyncThrottle::FIXED_DELAY_SECONDS).once

      throttle.wait_for_sync(target_path)
    end

    test 'lsof: wait_for_sync waits until file is opened then closed' do
      throttle = FileSyncThrottle.new(mode: :lsof)
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      open_sequence = [false, true, false]
      throttle.stubs(:file_open?).returns(*open_sequence)
      throttle.stubs(:wait)

      throttle.wait_for_sync(target_path)
    end
  end
end
