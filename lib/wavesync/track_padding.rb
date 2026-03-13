# frozen_string_literal: true

module Wavesync
  class TrackPadding
    BEATS_PER_BAR = 4

    def self.compute(duration_seconds, bpm, bar_multiple)
      return 0 if bpm.nil? || bpm.to_f.zero? || duration_seconds.nil? || duration_seconds <= 0

      seconds_per_bar = BEATS_PER_BAR * 60.0 / bpm.to_f
      track_bars = (duration_seconds / seconds_per_bar).round(6)
      target_bars = (track_bars / bar_multiple.to_f).ceil * bar_multiple

      padding = (target_bars * seconds_per_bar) - duration_seconds
      padding < 0.001 ? 0 : padding
    end

    def self.bar_counts(duration_seconds, bpm, bar_multiple)
      return [nil, nil] if bpm.nil? || bpm.to_f.zero? || duration_seconds.nil? || duration_seconds <= 0

      seconds_per_bar = BEATS_PER_BAR * 60.0 / bpm.to_f
      original_bars = (duration_seconds / seconds_per_bar).round
      target_bars = ((original_bars.to_f / bar_multiple).ceil * bar_multiple).to_i
      [original_bars, target_bars]
    end
  end
end
