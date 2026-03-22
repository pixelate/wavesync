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

    test 'wait_for_sync waits for the configured delay' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      @throttle.expects(:wait).with(FileSyncThrottle::DELAY_SECONDS).once

      @throttle.wait_for_sync(target_path)
    end
  end
end
