# frozen_string_literal: true

module Wavesync
  AudioFormat = Data.define(:file_type, :sample_rate, :bit_depth) do
    #: (AudioFormat other) -> AudioFormat
    def merge(other)
      with(
        file_type: other.file_type || file_type,
        sample_rate: other.sample_rate || sample_rate,
        bit_depth: other.bit_depth || bit_depth
      )
    end
  end
end
