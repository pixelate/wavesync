# frozen_string_literal: true

require 'pathname'
require_relative 'test_case'
require_relative '../../lib/wavesync/file_sync_throttle'

module Wavesync
  class FileSyncThrottleTest < Wavesync::TestCase
    def setup
      @throttle = FileSyncThrottle.new
      @tmpdir = Dir.mktmpdir
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    test 'wait_for_sync returns immediately when file size is stable on first poll' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio data')

      @throttle.wait_for_sync(target_path)
    end

    test 'wait_for_sync polls until size is stable' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      target_path.write('audio')

      sizes = [5, 10, 10]
      File.stubs(:size).with(target_path.to_s).returns(*sizes)
      @throttle.stubs(:wait)

      @throttle.wait_for_sync(target_path)
    end

    test 'wait_for_sync returns immediately when file does not exist' do
      target_path = Pathname.new(File.join(@tmpdir, 'missing.wav'))

      @throttle.wait_for_sync(target_path)
    end
  end
end
