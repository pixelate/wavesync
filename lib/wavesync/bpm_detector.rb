# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Wavesync
  class BpmDetector
    #: () -> bool?
    def self.available?
      system('which bpm > /dev/null 2>&1') && system('which ffmpeg > /dev/null 2>&1')
    end

    #: (String file_path) -> Integer?
    def self.detect(file_path)
      output = `ffmpeg -i #{Shellwords.escape(file_path)} -ac 1 -ar 44100 -f f32le - 2>/dev/null | bpm`
      bpm = output.strip.to_f
      bpm.positive? ? bpm.round : nil
    rescue StandardError
      nil
    end
  end
end
