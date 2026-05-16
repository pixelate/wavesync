# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'timing'

module Wavesync
  class CueChunk
    RIFF_HEADER_SIZE = 12
    CHUNK_ID_SIZE = 4
    CHUNK_SIZE_FIELD_SIZE = 4
    CUE_CHUNK_ID = 'cue '
    LIST_CHUNK_ID = 'LIST'
    ADTL_LIST_TYPE = 'adtl'
    LABL_CHUNK_ID = 'labl'
    NOTE_CHUNK_ID = 'note'
    DATA_CHUNK_ID = 'data'
    CUE_HEADER_SIZE = 4
    BYTES_PER_CUE_POINT = 24

    LOOP_START_NOTE = 'start'
    LOOP_END_NOTE = 'end'

    UINT32_LE = 'V'

    #: (String filepath) -> Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}]
    def self.read(filepath)
      Timing.current.measure(:wav_chunks) do
        cue_points = [] #: Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}]
        labels = {} #: Hash[Integer, String]
        notes = {} #: Hash[Integer, String]

        File.open(filepath, 'rb') do |file|
          file.seek(RIFF_HEADER_SIZE)

          until file.eof?
            chunk_id = file.read(CHUNK_ID_SIZE)
            break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

            chunk_size_bytes = file.read(CHUNK_SIZE_FIELD_SIZE)
            break if chunk_size_bytes.nil?

            chunk_size = chunk_size_bytes.unpack1(UINT32_LE).to_i
            chunk_data_start = file.tell

            if chunk_id == CUE_CHUNK_ID
              num_cues = file.read(4)&.unpack1(UINT32_LE).to_i
              num_cues.times do
                identifier = file.read(4)&.unpack1(UINT32_LE)&.to_i
                file.read(16) # skip position, fcc_chunk, chunk_start, block_start
                sample_offset = file.read(4)&.unpack1(UINT32_LE)&.to_i
                cue_points << { identifier: identifier, sample_offset: sample_offset, label: nil, note: nil } if identifier && sample_offset
              end
            elsif chunk_id == LIST_CHUNK_ID && chunk_size >= 4
              list_type = file.read(4)
              read_adtl_entries(file, chunk_data_start + chunk_size, labels, notes) if list_type == ADTL_LIST_TYPE
            end

            chunk_padding = chunk_size.odd? ? 1 : 0
            file.seek(chunk_data_start + chunk_size + chunk_padding)
          end
        end

        cue_points.map do |cue_point|
          {
            identifier: cue_point[:identifier],
            sample_offset: cue_point[:sample_offset],
            label: labels[cue_point[:identifier]],
            note: notes[cue_point[:identifier]]
          }
        end
      end
    end

    #: (Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points_a, Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points_b) -> bool
    def self.same?(cue_points_a, cue_points_b)
      to_comparable(cue_points_a) == to_comparable(cue_points_b)
    end

    #: (Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> Array[{sample_offset: Integer, label: String?, note: String?}]
    def self.to_comparable(cue_points)
      mapped = cue_points.map { |cp| { sample_offset: cp[:sample_offset], label: cp[:label], note: cp[:note] } } #: Array[{sample_offset: Integer, label: String?, note: String?}]
      mapped.sort_by { |cp| cp[:sample_offset] }
    end

    #: ({identifier: Integer, sample_offset: Integer, label: String?, note: String?} cue_point) -> bool
    def self.loop_marker?(cue_point)
      note = cue_point[:note]
      return false if note.nil?

      [LOOP_START_NOTE, LOOP_END_NOTE].include?(note)
    end

    #: (Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> Array[{start_sample: Integer, end_sample: Integer}]
    def self.loops(cue_points)
      starts = cue_points.select { |cue_point| cue_point[:note] == LOOP_START_NOTE }.sort_by { |cue_point| cue_point[:sample_offset] }
      ends = cue_points.select { |cue_point| cue_point[:note] == LOOP_END_NOTE }.sort_by { |cue_point| cue_point[:sample_offset] }
      starts.zip(ends).filter_map do |loop_start, loop_end|
        next nil unless loop_start && loop_end && loop_end[:sample_offset] > loop_start[:sample_offset]

        { start_sample: loop_start[:sample_offset], end_sample: loop_end[:sample_offset] }
      end
    end

    #: (String filepath, Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> void
    def self.append_to_file(filepath, cue_points)
      return if cue_points.empty?

      Timing.current.measure(:wav_chunks) do
        File.open(filepath, 'ab') do |file|
          write_cue_chunk(file, cue_points)
          write_adtl_chunk(file, cue_points) if cue_points.any? { |cue_point| cue_point[:label] || cue_point[:note] }
        end

        update_riff_size(filepath)
      end
    end

    #: (String source_filepath, String output_filepath, Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> void
    def self.write(source_filepath, output_filepath, cue_points)
      Timing.current.measure(:wav_chunks) do
        File.open(source_filepath, 'rb') do |input|
          File.open(output_filepath, 'wb') do |output|
            output.write(input.read(RIFF_HEADER_SIZE))

            until input.eof?
              chunk_id = input.read(CHUNK_ID_SIZE)
              break if chunk_id.nil? || chunk_id.length < CHUNK_ID_SIZE

              chunk_size_bytes = input.read(CHUNK_SIZE_FIELD_SIZE)
              break if chunk_size_bytes.nil?

              chunk_size = chunk_size_bytes.unpack1(UINT32_LE).to_i
              chunk_padding = chunk_size.odd? ? 1 : 0

              if chunk_id == CUE_CHUNK_ID
                input.read(chunk_size + chunk_padding)
              elsif chunk_id == LIST_CHUNK_ID && chunk_size >= 4
                list_type = input.read(4)
                if list_type == ADTL_LIST_TYPE
                  input.read(chunk_size - 4 + chunk_padding)
                else
                  output.write(chunk_id)
                  output.write(chunk_size_bytes)
                  output.write(list_type)
                  output.write(input.read(chunk_size - 4 + chunk_padding))
                end
              else
                output.write(chunk_id)
                output.write(chunk_size_bytes)
                output.write(input.read(chunk_size + chunk_padding))
              end
            end

            unless cue_points.empty?
              write_cue_chunk(output, cue_points)
              write_adtl_chunk(output, cue_points) if cue_points.any? { |cue_point| cue_point[:label] || cue_point[:note] }
            end
          end
        end

        update_riff_size(output_filepath)
      end
    end

    #: (untyped output, Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> void
    def self.write_cue_chunk(output, cue_points)
      chunk_size = CUE_HEADER_SIZE + (cue_points.size * BYTES_PER_CUE_POINT)
      output.write(CUE_CHUNK_ID)
      output.write([chunk_size].pack(UINT32_LE))
      output.write([cue_points.size].pack(UINT32_LE))
      cue_points.each_with_index do |cue_point, index|
        identifier = cue_point[:identifier] || (index + 1)
        output.write([identifier].pack(UINT32_LE))
        output.write([0].pack(UINT32_LE))
        output.write(DATA_CHUNK_ID)
        output.write([0].pack(UINT32_LE))
        output.write([0].pack(UINT32_LE))
        output.write([cue_point[:sample_offset]].pack(UINT32_LE))
      end
    end

    #: (untyped output, Array[{identifier: Integer, sample_offset: Integer, label: String?, note: String?}] cue_points) -> void
    def self.write_adtl_chunk(output, cue_points)
      entries = [] #: Array[{sub_id: String, identifier: Integer, text: String, data_size: Integer, pad: Integer}]
      cue_points.each do |cue_point|
        entries << build_adtl_entry(LABL_CHUNK_ID, cue_point[:identifier], cue_point[:label]) if cue_point[:label]
        entries << build_adtl_entry(NOTE_CHUNK_ID, cue_point[:identifier], cue_point[:note]) if cue_point[:note]
      end

      adtl_data_size = 4 + entries.sum { |entry| 8 + entry[:data_size] + entry[:pad] }
      output.write(LIST_CHUNK_ID)
      output.write([adtl_data_size].pack(UINT32_LE))
      output.write(ADTL_LIST_TYPE)

      entries.each do |entry|
        output.write(entry[:sub_id])
        output.write([entry[:data_size]].pack(UINT32_LE))
        output.write([entry[:identifier]].pack(UINT32_LE))
        output.write(entry[:text])
        output.write("\x00") if entry[:pad] == 1
      end
    end

    #: (String sub_id, Integer identifier, String text_content) -> {sub_id: String, identifier: Integer, text: String, data_size: Integer, pad: Integer}
    def self.build_adtl_entry(sub_id, identifier, text_content)
      text = "#{text_content}\x00"
      data_size = 4 + text.length
      pad = data_size.odd? ? 1 : 0
      { sub_id: sub_id, identifier: identifier, text: text, data_size: data_size, pad: pad }
    end

    #: (untyped file, Integer list_end, Hash[Integer, String] labels, Hash[Integer, String] notes) -> void
    def self.read_adtl_entries(file, list_end, labels, notes)
      while file.tell < list_end - 8
        sub_id = file.read(CHUNK_ID_SIZE)
        break if sub_id.nil? || sub_id.length < CHUNK_ID_SIZE

        sub_size_bytes = file.read(CHUNK_SIZE_FIELD_SIZE)
        break if sub_size_bytes.nil?

        sub_size = sub_size_bytes.unpack1(UINT32_LE).to_i
        sub_data_start = file.tell

        if [LABL_CHUNK_ID, NOTE_CHUNK_ID].include?(sub_id) && sub_size >= 4
          identifier = file.read(4)&.unpack1(UINT32_LE)&.to_i
          text_size = sub_size - 4
          text = text_size.positive? ? (file.read(text_size) || '') : ''
          target = sub_id == LABL_CHUNK_ID ? labels : notes
          target[identifier] = text.delete("\x00") if identifier
        end

        sub_padding = sub_size.odd? ? 1 : 0
        file.seek(sub_data_start + sub_size + sub_padding)
      end
    end

    #: (String filepath) -> void
    def self.update_riff_size(filepath)
      File.open(filepath, 'r+b') do |file|
        file.seek(0, IO::SEEK_END)
        file_size = file.tell
        riff_size = file_size - 8
        file.seek(4)
        file.write([riff_size].pack(UINT32_LE))
      end
    end
  end
end
