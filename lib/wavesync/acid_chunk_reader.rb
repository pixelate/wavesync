# frozen_string_literal: true

module Wavesync
  class AcidChunkReader
    RIFF_HEADER_SIZE = 12 # 'RIFF' (4) + size (4) + 'WAVE' (4)

    CHUNK_ID_SIZE = 4
    CHUNK_SIZE_FIELD_SIZE = 4
    ACID_CHUNK_ID = 'acid'

    ACID_CHUNK_DATA_SIZE = 24
    ACID_TYPE_FLAGS_SIZE = 4
    ACID_ROOT_NOTE_SIZE = 2
    ACID_UNKNOWN1_SIZE = 2
    ACID_UNKNOWN2_SIZE = 4
    ACID_NUM_BEATS_SIZE = 4
    ACID_METER_DENOM_SIZE = 2
    ACID_METER_NUMER_SIZE = 2
    ACID_TEMPO_SIZE = 4

    # Offset to tempo field within ACID chunk data (skip first 20 bytes)
    ACID_TEMPO_OFFSET = ACID_TYPE_FLAGS_SIZE +
                        ACID_ROOT_NOTE_SIZE +
                        ACID_UNKNOWN1_SIZE +
                        ACID_UNKNOWN2_SIZE +
                        ACID_NUM_BEATS_SIZE +
                        ACID_METER_DENOM_SIZE +
                        ACID_METER_NUMER_SIZE

    UINT32_LITTLE_ENDIAN = 'V'
    FLOAT32_LITTLE_ENDIAN = 'e'

    def self.extract_bpm(filepath)
      File.open(filepath, 'rb') do |file|
        file.seek(RIFF_HEADER_SIZE)

        until file.eof?
          chunk_id = file.read(CHUNK_ID_SIZE)
          break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

          chunk_size = file.read(CHUNK_SIZE_FIELD_SIZE).unpack1(UINT32_LITTLE_ENDIAN)

          if chunk_id == ACID_CHUNK_ID
            file.seek(ACID_TEMPO_OFFSET, IO::SEEK_CUR)
            return file.read(ACID_TEMPO_SIZE).unpack1(FLOAT32_LITTLE_ENDIAN)
          else
            padding = chunk_size.odd? ? 1 : 0
            file.seek(chunk_size + padding, IO::SEEK_CUR)
          end
        end
      end

      nil
    end
  end
end
