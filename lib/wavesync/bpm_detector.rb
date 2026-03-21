# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'essentia_bpm_detector'
require_relative 'percival_bpm_detector'

module Wavesync
  class BpmDetector
    CONFIDENCE_THRESHOLD = 2.0

    #: () -> bool?
    def self.available?
      EssentiaBpmDetector.available? || PercivalBpmDetector.available?
    end

    #: (String file_path) -> Integer?
    def self.detect(file_path)
      if EssentiaBpmDetector.available?
        essentia_result = EssentiaBpmDetector.detect(file_path)
        return essentia_result[:bpm] if essentia_result && essentia_result[:confidence] > CONFIDENCE_THRESHOLD
      end

      PercivalBpmDetector.detect(file_path) if PercivalBpmDetector.available?
    end
  end
end
