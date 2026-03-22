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

    test 'wait_for_sync returns immediately when free space exceeds threshold' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      @throttle.stubs(:free_space_bytes).returns(FileSyncThrottle::FREE_SPACE_THRESHOLD_BYTES + 1)

      @throttle.wait_for_sync(target_path)
    end

    test 'wait_for_sync polls until free space recovers above threshold' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      free_space_sequence = [
        FileSyncThrottle::FREE_SPACE_THRESHOLD_BYTES - 1,
        FileSyncThrottle::FREE_SPACE_THRESHOLD_BYTES - 1,
        FileSyncThrottle::FREE_SPACE_THRESHOLD_BYTES + 1
      ]
      @throttle.stubs(:free_space_bytes).returns(*free_space_sequence)
      @throttle.stubs(:wait)

      @throttle.wait_for_sync(target_path)
    end
  end
end
