# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/logger'
require_relative '../../lib/wavesync/essentia_bpm_detector'

module Wavesync
  class EssentiaBpmDetectorTest < Wavesync::TestCase
    test 'detect returns rounded BPM and confidence from essentia output' do
      PythonVenv.stubs(:run_script).returns('{"bpm": 120, "confidence": 0.87, "first_downbeat_position": 0.0}')
      result = EssentiaBpmDetector.detect('/fake/file.wav')
      assert_equal 120, result[:bpm]
      assert_equal 0.87, result[:confidence]
      assert_equal 0.0, result[:first_downbeat_position]
    end

    test 'detect returns first_downbeat_position when track does not start on ONE' do
      PythonVenv.stubs(:run_script).returns('{"bpm": 120, "confidence": 3.5, "first_downbeat_position": 1.5}')
      result = EssentiaBpmDetector.detect('/fake/file.wav')
      assert_equal 1.5, result[:first_downbeat_position]
    end

    test 'detect rounds BPM up correctly' do
      PythonVenv.stubs(:run_script).returns('{"bpm": 121, "confidence": 0.75, "first_downbeat_position": 0.0}')
      result = EssentiaBpmDetector.detect('/fake/file.wav')
      assert_equal 121, result[:bpm]
    end

    test 'detect returns nil when output is empty' do
      PythonVenv.stubs(:run_script).returns('')
      assert_nil EssentiaBpmDetector.detect('/fake/file.wav')
    end

    test 'detect returns nil when BPM is zero' do
      PythonVenv.stubs(:run_script).returns('{"bpm": 0, "confidence": 0.0, "first_downbeat_position": 0.0}')
      assert_nil EssentiaBpmDetector.detect('/fake/file.wav')
    end

    test 'detect logs error with file_path when an exception occurs' do
      error = StandardError.new('script failed')
      PythonVenv.stubs(:run_script).raises(error)
      Logger.expects(:log_error).with(error, call_site: 'EssentiaBpmDetector.detect', arguments: { file_path: '/fake/file.wav' })
      EssentiaBpmDetector.detect('/fake/file.wav')
    end
  end
end
