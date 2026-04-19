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

    #: (String file_path) -> {bpm: Integer, first_downbeat_position: Float}?
    def self.detect_with_downbeat(file_path)
      if EssentiaBpmDetector.available?
        essentia_result = EssentiaBpmDetector.detect(file_path)
        return { bpm: essentia_result[:bpm], first_downbeat_position: essentia_result[:first_downbeat_position] } if essentia_result && essentia_result[:confidence] > CONFIDENCE_THRESHOLD
      end

      if PercivalBpmDetector.available?
        bpm = PercivalBpmDetector.detect(file_path)
        return { bpm: bpm, first_downbeat_position: 0.0 } if bpm
      end

      nil
    end
  end
end
