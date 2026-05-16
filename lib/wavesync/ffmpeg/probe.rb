# frozen_string_literal: true
# rbs_inline: enabled

require 'open3'
require 'json'
require_relative '../timing'

module Wavesync
  class FFMPEG
    class Probe
      #: (String file_path) -> void
      def initialize(file_path)
        @file_path = file_path #: String
      end

      #: () -> Float
      def duration
        format_data.fetch('duration', '0').to_f
      end

      #: () -> Integer?
      def sample_rate
        rate = audio_stream&.fetch('sample_rate', nil)
        rate&.to_i
      end

      #: () -> Integer?
      def bit_depth
        bits = audio_stream&.fetch('bits_per_sample', nil)&.to_i
        bits&.positive? ? bits : nil
      end

      #: () -> Integer?
      def bitrate
        bits_per_second = audio_stream&.fetch('bit_rate', nil)&.to_i
        return nil unless bits_per_second&.positive?

        (bits_per_second / 1000.0).round
      end

      #: () -> Hash[String, String]
      def tags
        format_data['tags'] || {}
      end

      private

      #: () -> Hash[String, untyped]
      def probe_data
        @probe_data ||= run_probe
      end

      #: () -> Hash[String, untyped]
      def run_probe
        ffprobe = FFMPEG.binary.sub('ffmpeg', 'ffprobe')
        stdout = Timing.current.measure(:probe) do
          out, _stderr, _status = Open3.capture3(
            ffprobe, '-v', 'quiet', '-print_format', 'json',
            '-show_streams', '-show_format', @file_path
          )
          out
        end
        JSON.parse(stdout)
      end

      #: () -> Hash[String, untyped]
      def format_data
        probe_data['format'] || {} #: Hash[String, untyped]
      end

      #: () -> Hash[String, untyped]?
      def audio_stream
        streams = probe_data['streams'] || [] #: Array[Hash[String, untyped]]
        @audio_stream ||= streams.find { |stream| stream['codec_type'] == 'audio' }
      end
    end
  end
end
