# frozen_string_literal: true

require_relative '../test_case'
require_relative '../../../lib/wavesync/ffmpeg'

module Wavesync
  class FFMPEG
    class ProbeTest < Wavesync::TestCase
      test 'duration returns the duration of a wav file' do
        assert_in_delta 1.0, probe('44100_16.wav').duration, 0.1
      end

      test 'duration returns the duration of an m4a file' do
        assert_in_delta 1.0, probe('44100.m4a').duration, 0.1
      end

      test 'sample_rate returns the sample rate of a wav file' do
        assert_equal 44_100, probe('44100_16.wav').sample_rate
      end

      test 'sample_rate returns the sample rate of an mp3 file' do
        assert_equal 44_100, probe('44100.mp3').sample_rate
      end

      test 'sample_rate returns the sample rate of an m4a file' do
        assert_equal 44_100, probe('44100.m4a').sample_rate
      end

      test 'bit_depth returns 8 for an 8-bit wav' do
        assert_equal 8, probe('44100_8.wav').bit_depth
      end

      test 'bit_depth returns 16 for a 16-bit wav' do
        assert_equal 16, probe('44100_16.wav').bit_depth
      end

      test 'bit_depth returns 24 for a 24-bit wav' do
        assert_equal 24, probe('44100_24.wav').bit_depth
      end

      test 'bit_depth returns nil for mp3' do
        assert_nil probe('44100.mp3').bit_depth
      end

      test 'bit_depth returns nil for m4a' do
        assert_nil probe('44100.m4a').bit_depth
      end

      test 'bitrate returns kbps for mp3' do
        assert probe('44100.mp3').bitrate.positive?
      end

      private

      def probe(name)
        Probe.new(File.join(FIXTURES_PATH, name))
      end
    end
  end
end
