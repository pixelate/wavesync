# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  class Timing
    BUCKETS = %i[transcode probe ffmpeg_metadata copy wav_chunks filesystem].freeze

    #: () -> Timing
    def self.current
      @current ||= new
    end

    #: () -> void
    def self.reset
      @current = new
    end

    #: () -> void
    def initialize
      @totals = Hash.new(0.0) #: Hash[Symbol, Float]
    end

    #: (Symbol bucket) { () -> untyped } -> untyped
    def measure(bucket)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
    ensure
      @totals[bucket] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end

    #: () -> Hash[Symbol, Float]
    def totals
      @totals.dup
    end
  end
end
