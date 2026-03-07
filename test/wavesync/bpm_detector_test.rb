# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/bpm_detector'

module Wavesync
  class BpmDetectorTest < Wavesync::TestCase
    test 'detect returns rounded BPM from bpm-tools output' do
      BpmDetector.stubs(:`).returns("120.4\n")
      assert_equal 120, BpmDetector.detect('/fake/file.wav')
    end

    test 'detect rounds up correctly' do
      BpmDetector.stubs(:`).returns("120.6\n")
      assert_equal 121, BpmDetector.detect('/fake/file.wav')
    end

    test 'detect returns nil when output is empty' do
      BpmDetector.stubs(:`).returns('')
      assert_nil BpmDetector.detect('/fake/file.wav')
    end

    test 'detect returns nil when BPM is zero' do
      BpmDetector.stubs(:`).returns("0.0\n")
      assert_nil BpmDetector.detect('/fake/file.wav')
    end
  end
end
