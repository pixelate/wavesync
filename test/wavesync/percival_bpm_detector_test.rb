# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/percival_bpm_detector'

module Wavesync
  class PercivalBpmDetectorTest < Wavesync::TestCase
    test 'detect returns rounded BPM from percival output' do
      PythonVenv.stubs(:run_script).returns("120.4\n")
      assert_equal 120, PercivalBpmDetector.detect('/fake/file.wav')
    end

    test 'detect rounds up correctly' do
      PythonVenv.stubs(:run_script).returns("120.6\n")
      assert_equal 121, PercivalBpmDetector.detect('/fake/file.wav')
    end

    test 'detect returns nil when output is empty' do
      PythonVenv.stubs(:run_script).returns('')
      assert_nil PercivalBpmDetector.detect('/fake/file.wav')
    end

    test 'detect returns nil when BPM is zero' do
      PythonVenv.stubs(:run_script).returns("0.0\n")
      assert_nil PercivalBpmDetector.detect('/fake/file.wav')
    end
  end
end
