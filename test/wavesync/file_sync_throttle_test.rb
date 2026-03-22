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

    test 'wait_for_sync waits for file to be opened then closed' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      open_sequence = [false, false, true, true, false]
      @throttle.stubs(:file_open?).with(target_path).returns(*open_sequence)
      @throttle.stubs(:wait)

      @throttle.wait_for_sync(target_path)
    end

    test 'wait_for_sync returns when deadline is reached before file is opened' do
      target_path = Pathname.new(File.join(@tmpdir, 'track.wav'))
      @throttle.stubs(:file_open?).returns(false)
      @throttle.stubs(:wait)

      now = Time.now
      Time.stubs(:now).returns(now, now + FileSyncThrottle::TIMEOUT_SECONDS + 1)

      @throttle.wait_for_sync(target_path)
    end
  end
end
