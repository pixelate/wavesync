# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'timing'

module Wavesync
  class AcidChunk
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

    ACID_TEMPO_OFFSET = ACID_TYPE_FLAGS_SIZE +
                        ACID_ROOT_NOTE_SIZE +
                        ACID_UNKNOWN1_SIZE +
                        ACID_UNKNOWN2_SIZE +
                        ACID_NUM_BEATS_SIZE +
                        ACID_METER_DENOM_SIZE +
                        ACID_METER_NUMER_SIZE

    UINT32_LITTLE_ENDIAN = 'V'
    FLOAT32_LITTLE_ENDIAN = 'e'

    #: (String filepath) -> Float?
    def self.read_bpm(filepath)
      Timing.current.measure(:wav_chunks) do
        result = nil #: Float?
        File.open(filepath, 'rb') do |file|
          file.seek(RIFF_HEADER_SIZE)
          until file.eof?
            chunk_id = file.read(CHUNK_ID_SIZE)
            break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

            chunk_size = ((file.read(CHUNK_SIZE_FIELD_SIZE) || '').unpack1(UINT32_LITTLE_ENDIAN) || 0).to_i
            if chunk_id == ACID_CHUNK_ID
              file.seek(ACID_TEMPO_OFFSET, IO::SEEK_CUR)
              result = ((file.read(ACID_TEMPO_SIZE) || '').unpack1(FLOAT32_LITTLE_ENDIAN) || 0).to_f
              break
            else
              padding = chunk_size.odd? ? 1 : 0
              file.seek(chunk_size + padding, IO::SEEK_CUR)
            end
          end
        end
        result
      end
    end

    #: (String filepath, Integer | Float | String new_bpm) -> void
    def self.write_bpm_in_place(filepath, new_bpm)
      Timing.current.measure(:wav_chunks) do
        bpm_bytes = [new_bpm.to_f].pack(FLOAT32_LITTLE_ENDIAN)

        File.open(filepath, 'r+b') do |file|
          file.seek(RIFF_HEADER_SIZE)

          acid_chunk_found = false

          until file.eof?
            chunk_id = file.read(CHUNK_ID_SIZE)
            break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

            chunk_size_bytes = file.read(CHUNK_SIZE_FIELD_SIZE) || ''
            chunk_size = (chunk_size_bytes.unpack1(UINT32_LITTLE_ENDIAN) || 0).to_i

            if chunk_id == ACID_CHUNK_ID
              file.seek(ACID_TEMPO_OFFSET, IO::SEEK_CUR)
              file.write(bpm_bytes)
              acid_chunk_found = true
              break
            else
              padding = chunk_size.odd? ? 1 : 0
              file.seek(chunk_size + padding, IO::SEEK_CUR)
            end
          end

          unless acid_chunk_found
            file.seek(0, IO::SEEK_END)
            create_acid_chunk(file, new_bpm.to_f)
          end
        end

        update_riff_size(filepath)
      end
    end

    #: (String source_filepath, String output_filepath, Integer | Float | String new_bpm) -> void
    def self.write_bpm(source_filepath, output_filepath, new_bpm)
      Timing.current.measure(:wav_chunks) do
        bpm_bytes = [new_bpm.to_f].pack(FLOAT32_LITTLE_ENDIAN)
        acid_chunk_found = false

        File.open(source_filepath, 'rb') do |input|
          File.open(output_filepath, 'wb') do |output|
            riff_header = input.read(RIFF_HEADER_SIZE)
            output.write(riff_header)

            until input.eof?
              chunk_id = input.read(CHUNK_ID_SIZE)
              break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

              chunk_size_bytes = input.read(CHUNK_SIZE_FIELD_SIZE) || ''
              chunk_size = (chunk_size_bytes.unpack1(UINT32_LITTLE_ENDIAN) || 0).to_i

              output.write(chunk_id)
              output.write(chunk_size_bytes)

              if chunk_id == ACID_CHUNK_ID
                acid_chunk_found = true

                output.write(input.read(ACID_TEMPO_OFFSET))

                input.read(ACID_TEMPO_SIZE)

                output.write(bpm_bytes)

                remaining = chunk_size - ACID_TEMPO_OFFSET - ACID_TEMPO_SIZE
                output.write(input.read(remaining)) if remaining.positive?

                output.write(input.read(1)) if chunk_size.odd?
              else
                padding = chunk_size.odd? ? 1 : 0
                output.write(input.read(chunk_size + padding))
              end
            end

            create_acid_chunk(output, new_bpm.to_f) unless acid_chunk_found
          end
        end

        next if acid_chunk_found

        update_riff_size(output_filepath)
      end
    end

    #: (untyped output, Float bpm) -> void
    def self.create_acid_chunk(output, bpm)
      # Write ACID chunk ID
      output.write(ACID_CHUNK_ID)

      # Write chunk size (24 bytes)
      output.write([ACID_CHUNK_DATA_SIZE].pack(UINT32_LITTLE_ENDIAN))

      # Type flags (4 bytes) - 0x01 for one-shot
      output.write([0x01].pack(UINT32_LITTLE_ENDIAN))

      # Root note (2 bytes) - 0x003C (middle C / 60)
      output.write([0x003C].pack('v'))

      # Unknown1 (2 bytes)
      output.write([0x0000].pack('v'))

      # Unknown2 (4 bytes)
      output.write([0x00000000].pack(UINT32_LITTLE_ENDIAN))

      # Number of beats (4 bytes) - 0 for non-loop
      output.write([0x00000000].pack(UINT32_LITTLE_ENDIAN))

      # Meter denominator (2 bytes) - 4 for 4/4 time
      output.write([0x0004].pack('v'))

      # Meter numerator (2 bytes) - 4 for 4/4 time
      output.write([0x0004].pack('v'))

      output.write([bpm].pack(FLOAT32_LITTLE_ENDIAN))
    end

    #: (String filepath) -> void
    def self.update_riff_size(filepath)
      File.open(filepath, 'r+b') do |file|
        file.seek(0, IO::SEEK_END)
        file_size = file.tell

        riff_size = file_size - 8

        file.seek(4)
        file.write([riff_size].pack(UINT32_LITTLE_ENDIAN))
      end
    end
  end
end
