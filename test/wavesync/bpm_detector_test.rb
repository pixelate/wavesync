# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/bpm_detector'

module Wavesync
  class BpmDetectorTest < Wavesync::TestCase
    def setup
      EssentiaBpmDetector.stubs(:available?).returns(true)
      PercivalBpmDetector.stubs(:available?).returns(true)
    end

    test 'uses essentia BPM when confidence exceeds threshold' do
      EssentiaBpmDetector.stubs(:detect).returns({ bpm: 128, confidence: 2.5 })
      assert_equal 128, BpmDetector.detect('/fake/file.wav')
    end

    test 'falls back to percival when essentia confidence is below threshold' do
      EssentiaBpmDetector.stubs(:detect).returns({ bpm: 162, confidence: 1.4 })
      PercivalBpmDetector.stubs(:detect).returns(80)
      assert_equal 80, BpmDetector.detect('/fake/file.wav')
    end

    test 'falls back to percival when essentia returns nil' do
      EssentiaBpmDetector.stubs(:detect).returns(nil)
      PercivalBpmDetector.stubs(:detect).returns(120)
      assert_equal 120, BpmDetector.detect('/fake/file.wav')
    end

    test 'uses percival when essentia is unavailable' do
      EssentiaBpmDetector.stubs(:available?).returns(false)
      PercivalBpmDetector.stubs(:detect).returns(120)
      assert_equal 120, BpmDetector.detect('/fake/file.wav')
    end

    test 'returns nil when both detectors are unavailable' do
      EssentiaBpmDetector.stubs(:available?).returns(false)
      PercivalBpmDetector.stubs(:available?).returns(false)
      assert_nil BpmDetector.detect('/fake/file.wav')
    end

    test 'available? returns true when essentia is available' do
      EssentiaBpmDetector.stubs(:available?).returns(true)
      PercivalBpmDetector.stubs(:available?).returns(false)
      assert BpmDetector.available?
    end

    test 'available? returns true when percival is available' do
      EssentiaBpmDetector.stubs(:available?).returns(false)
      PercivalBpmDetector.stubs(:available?).returns(true)
      assert BpmDetector.available?
    end

    test 'available? returns false when neither detector is available' do
      EssentiaBpmDetector.stubs(:available?).returns(false)
      PercivalBpmDetector.stubs(:available?).returns(false)
      refute BpmDetector.available?
    end
  end
end
