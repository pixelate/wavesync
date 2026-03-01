# frozen_string_literal: true

module Wavesync
  # Reads and writes ACID chunk metadata in WAV files,
  # used to store BPM information for loop-aware devices.
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

    def self.read_bpm(filepath)
      File.open(filepath, 'rb') do |file|
        file.seek(RIFF_HEADER_SIZE)
        until file.eof?
          chunk_id, _, chunk_size = read_chunk_header(file)
          break unless chunk_id

          return read_acid_tempo(file) if chunk_id == ACID_CHUNK_ID

          file.seek(chunk_size + (chunk_size.odd? ? 1 : 0), IO::SEEK_CUR)
        end
      end
      nil
    end

    def self.write_bpm(source_filepath, output_filepath, new_bpm)
      bpm_bytes = [new_bpm.to_f].pack(FLOAT32_LITTLE_ENDIAN)
      acid_found = false
      File.open(source_filepath, 'rb') do |input|
        File.open(output_filepath, 'wb') do |output|
          output.write(input.read(RIFF_HEADER_SIZE))
          acid_found = process_chunks(input, output, bpm_bytes)
        end
      end
      update_riff_size(output_filepath) unless acid_found
    end

    def self.update_riff_size(filepath)
      File.open(filepath, 'r+b') do |file|
        file.seek(0, IO::SEEK_END)
        file_size = file.tell
        riff_size = file_size - 8
        file.seek(4)
        file.write([riff_size].pack(UINT32_LITTLE_ENDIAN))
      end
    end

    def self.read_chunk_header(file)
      chunk_id = file.read(CHUNK_ID_SIZE)
      return unless chunk_id&.length == CHUNK_ID_SIZE

      chunk_size_bytes = file.read(CHUNK_SIZE_FIELD_SIZE)
      [chunk_id, chunk_size_bytes, chunk_size_bytes.unpack1(UINT32_LITTLE_ENDIAN)]
    end

    def self.read_acid_tempo(file)
      file.seek(ACID_TEMPO_OFFSET, IO::SEEK_CUR)
      file.read(ACID_TEMPO_SIZE).unpack1(FLOAT32_LITTLE_ENDIAN)
    end

    def self.process_chunks(input, output, bpm_bytes)
      acid_found = false
      until input.eof?
        chunk_id, chunk_size_bytes, chunk_size = read_chunk_header(input)
        break unless chunk_id

        output.write(chunk_id + chunk_size_bytes)
        acid_found ||= write_chunk(input, output, chunk_id, chunk_size, bpm_bytes)
      end
      create_acid_chunk(output, bpm_bytes) unless acid_found
      acid_found
    end

    def self.write_chunk(input, output, chunk_id, chunk_size, bpm_bytes)
      if chunk_id == ACID_CHUNK_ID
        write_acid_chunk_bpm(input, output, chunk_size, bpm_bytes)
        true
      else
        output.write(input.read(chunk_size + (chunk_size.odd? ? 1 : 0)))
        false
      end
    end

    def self.write_acid_chunk_bpm(input, output, chunk_size, bpm_bytes)
      output.write(input.read(ACID_TEMPO_OFFSET))
      input.read(ACID_TEMPO_SIZE)
      output.write(bpm_bytes)
      remaining = chunk_size - ACID_TEMPO_OFFSET - ACID_TEMPO_SIZE
      output.write(input.read(remaining)) if remaining.positive?
      output.write(input.read(1)) if chunk_size.odd?
    end

    def self.create_acid_chunk(output, bpm_bytes)
      payload = [0x01, 0x003C, 0x0000, 0x00000000, 0x00000000, 0x0004, 0x0004].pack('VvvVVvv')
      output.write(ACID_CHUNK_ID + [ACID_CHUNK_DATA_SIZE].pack(UINT32_LITTLE_ENDIAN) + payload + bpm_bytes)
    end

    private_class_method :read_chunk_header, :read_acid_tempo, :process_chunks,
                         :write_chunk, :write_acid_chunk_bpm, :create_acid_chunk
  end
end
