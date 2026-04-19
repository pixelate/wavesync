# frozen_string_literal: true

module Wavesync
  AudioFormat = Data.define(:file_type, :sample_rate, :bit_depth, :bitrate) do
    #: (file_type: String?, sample_rate: Integer?, bit_depth: Integer?, ?bitrate: Integer?) -> void
    def initialize(file_type:, sample_rate:, bit_depth:, bitrate: nil)
      super
    end

    #: (AudioFormat other) -> AudioFormat
    def merge(other)
      with(
        file_type: other.file_type || file_type,
        sample_rate: other.sample_rate || sample_rate,
        bit_depth: other.bit_depth || bit_depth,
        bitrate: other.bitrate || bitrate
      )
    end
  end
end
