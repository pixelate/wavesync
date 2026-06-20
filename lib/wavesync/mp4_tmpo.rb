# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require_relative 'timing'

module Wavesync
  # Reads and writes the iTunes `tmpo` atom (BPM) in MP4/M4A files.
  #
  # ffmpeg/ffprobe cannot read or write `tmpo`, so we parse the atom tree
  # directly — the same hand-rolled approach used for WAV in `AcidChunk` and
  # `CueChunk`. `tmpo` lives at moov → udta → meta → ilst → tmpo → data, where
  # the value is a big-endian integer. This is the form Apple Music writes and
  # the one `AVFoundation` (and thus audioplayer) reads.
  class Mp4Tmpo
    HEADER_SIZE = 8         # box size (4) + type (4)
    TYPE_SIZE = 4
    FULLBOX_FLAGS_SIZE = 4  # version (1) + flags (3)
    LOCALE_SIZE = 4         # `data` atom locale field
    DATA_TYPE_UTF8 = 1
    DATA_TYPE_INTEGER = 21

    UINT16 = 'n'            # iTunes stores BPM as a 16-bit big-endian integer
    UINT32 = 'N'
    UINT64 = 'Q>'
    ZERO_FLAGS = [0].pack(UINT32).freeze

    #: (String filepath) -> Integer?
    def self.read_bpm(filepath)
      Timing.current.measure(:mp4_chunks) do
        data = File.binread(filepath).b
        ilst = locate_ilst(data)
        next nil unless ilst

        value = tmpo_value(data, ilst[0], ilst[1])
        value&.positive? ? value : nil
      end
    end

    #: (String filepath, Integer | Float | String bpm) -> void
    def self.write_bpm(filepath, bpm)
      Timing.current.measure(:mp4_chunks) do
        data = File.binread(filepath).b
        updated = set_tmpo(data, bpm.to_i)
        next if updated.equal?(data)

        temp_path = "#{filepath}.tmp"
        File.binwrite(temp_path, updated)
        FileUtils.mv(temp_path, filepath)
      end
    end

    # --- reading -------------------------------------------------------------

    #: (String data, Integer ilst_start, Integer ilst_finish) -> Integer?
    def self.tmpo_value(data, ilst_start, ilst_finish)
      tmpo = find_box(data, 'tmpo', ilst_start, ilst_finish)
      return nil unless tmpo

      t_off, t_size, t_hdr = tmpo
      box = find_box(data, 'data', t_off + t_hdr, t_off + t_size)
      return nil unless box

      d_off, d_size, d_hdr = box
      type_flag = u32(data, d_off + d_hdr) & 0xFFFFFF
      value_start = d_off + d_hdr + FULLBOX_FLAGS_SIZE + LOCALE_SIZE
      bytes = data[value_start, (d_off + d_size) - value_start] || ''
      decode_value(bytes, type_flag)
    end

    #: (String bytes, Integer type_flag) -> Integer?
    def self.decode_value(bytes, type_flag)
      return bytes.to_i if type_flag == DATA_TYPE_UTF8

      bytes.bytes.reduce(0) { |acc, byte| (acc << 8) | byte }
    end

    # Returns the byte range [start, finish) spanning the ilst children, or nil.
    #: (String data) -> [Integer, Integer]?
    def self.locate_ilst(data)
      moov = find_box(data, 'moov', 0, data.bytesize)
      return nil unless moov

      udta = find_box(data, 'udta', moov[0] + moov[2], moov[0] + moov[1])
      return nil unless udta

      meta = find_box(data, 'meta', udta[0] + udta[2], udta[0] + udta[1])
      return nil unless meta

      meo, mes, meh = meta
      children_start = meo + meh + meta_prefix_size(data[meo + meh, mes - meh] || '')
      ilst = find_box(data, 'ilst', children_start, meo + mes)
      return nil unless ilst

      io, isz, ih = ilst
      [io + ih, io + isz]
    end

    # --- writing -------------------------------------------------------------

    # Rebuilds the moov atom with `tmpo` set to `bpm`, fixing up chunk offsets
    # if moov precedes mdat. Returns the same object unchanged when there is no
    # moov atom (not an MP4 we understand).
    #: (String data, Integer bpm) -> String
    def self.set_tmpo(data, bpm)
      moov = find_box(data, 'moov', 0, data.bytesize)
      return data unless moov

      mo, ms, = moov
      new_moov = rebuild_moov(data[mo, ms] || '', build_tmpo(bpm))
      delta = new_moov.bytesize - ms

      mdat = find_box(data, 'mdat', 0, data.bytesize)
      new_moov = patch_chunk_offsets(new_moov, delta) if delta != 0 && mdat && mo < mdat[0]

      "#{data[0, mo]}#{new_moov}#{data[(mo + ms)..]}"
    end

    #: (String moov, String tmpo_box) -> String
    def self.rebuild_moov(moov, tmpo_box)
      hdr = box_header_size(moov, 0)
      payload = moov[hdr..] || ''

      new_payload = update_container(payload, 'udta') do |udta|
        update_container(udta, 'meta') do |meta|
          prefix = meta_prefix(meta)
          body = meta[prefix.bytesize..] || ''
          prefix + update_container(body, 'ilst') { |ilst| set_tmpo_box(ilst, tmpo_box) }
        end
      end

      box('moov', new_payload)
    end

    # Replaces the child of `type` in `payload` with the result of the block
    # (called with the child's payload), or appends a new child if absent.
    #: (String payload, String type) { (String) -> String } -> String
    def self.update_container(payload, type)
      found = find_box(payload, type, 0, payload.bytesize)
      if found
        off, size, hdr = found
        new_child = yield(payload[off + hdr, size - hdr] || '')
        "#{payload[0, off]}#{box(type, new_child)}#{payload[(off + size)..]}"
      else
        payload + box(type, yield(''))
      end
    end

    #: (String ilst, String tmpo_box) -> String
    def self.set_tmpo_box(ilst, tmpo_box)
      found = find_box(ilst, 'tmpo', 0, ilst.bytesize)
      return ilst + tmpo_box unless found

      off, size, = found
      "#{ilst[0, off]}#{tmpo_box}#{ilst[(off + size)..]}"
    end

    #: (Integer bpm) -> String
    def self.build_tmpo(bpm)
      value = [clamp_uint16(bpm)].pack(UINT16)
      data_payload = [DATA_TYPE_INTEGER].pack(UINT32) + [0].pack(UINT32) + value
      box('tmpo', box('data', data_payload))
    end

    # Adds `delta` to every stco/co64 chunk offset, so audio data references
    # stay valid after moov grows ahead of mdat.
    #: (String moov, Integer delta) -> String
    def self.patch_chunk_offsets(moov, delta)
      moov = moov.b
      each_descendant(moov, 0, moov.bytesize, %w[moov trak mdia minf stbl]) do |type, off, _size, hdr|
        next unless %w[stco co64].include?(type)

        count = u32(moov, off + hdr + FULLBOX_FLAGS_SIZE)
        base = off + hdr + FULLBOX_FLAGS_SIZE + 4
        count.times do |i|
          if type == 'stco'
            pos = base + (i * 4)
            moov[pos, 4] = [(u32(moov, pos) + delta) & 0xFFFFFFFF].pack(UINT32)
          else
            pos = base + (i * 8)
            moov[pos, 8] = [u64(moov, pos) + delta].pack(UINT64)
          end
        end
      end
      moov
    end

    # --- atom helpers --------------------------------------------------------

    #: (String type, String payload) -> String
    def self.box(type, payload)
      [HEADER_SIZE + payload.bytesize].pack(UINT32) + type + payload
    end

    # `meta` is a FullBox in MP4 (4-byte version/flags before its children) but
    # a plain box in some QuickTime files. Detect which, and synthesize a valid
    # FullBox header (with an `mdir` handler) when creating `meta` from scratch.
    #: (String meta_payload) -> String
    def self.meta_prefix(meta_payload)
      return ZERO_FLAGS + hdlr_mdir_box if meta_payload.empty?
      return '' if non_fullbox_meta?(meta_payload)

      meta_payload[0, FULLBOX_FLAGS_SIZE] || ''
    end

    #: (String meta_payload) -> Integer
    def self.meta_prefix_size(meta_payload)
      meta_prefix(meta_payload).bytesize
    end

    # A plain (non-FullBox) meta starts with a child box, so a known child type
    # ('hdlr') appears at the type offset of the first box.
    #: (String meta_payload) -> bool
    def self.non_fullbox_meta?(meta_payload)
      meta_payload[TYPE_SIZE, TYPE_SIZE] == 'hdlr'
    end

    #: () -> String
    def self.hdlr_mdir_box
      payload = "#{ZERO_FLAGS}#{[0].pack(UINT32)}mdirappl#{[0].pack(UINT32) * 2}\u0000" # empty name, null-terminated
      box('hdlr', payload)
    end

    # Returns [offset, size, header_size] of the first direct child of `type`
    # within [start, finish), or nil.
    #: (String data, String type, Integer start, Integer finish) -> [Integer, Integer, Integer]?
    def self.find_box(data, type, start, finish)
      result = nil #: [Integer, Integer, Integer]?
      each_box(data, start, finish) do |t, off, size, hdr|
        if t == type
          result = [off, size, hdr]
          break
        end
      end
      result
    end

    #: (String data, Integer start, Integer finish) { (String, Integer, Integer, Integer) -> void } -> void
    def self.each_box(data, start, finish)
      pos = start
      while pos + HEADER_SIZE <= finish
        size = u32(data, pos)
        hdr = HEADER_SIZE
        if size == 1
          size = u64(data, pos + HEADER_SIZE)
          hdr = 16
        elsif size.zero?
          size = finish - pos
        end
        break if size < hdr || pos + size > finish

        yield data[pos + 4, TYPE_SIZE] || '', pos, size, hdr
        pos += size
      end
    end

    #: (String data, Integer start, Integer finish, Array[String] containers) { (String, Integer, Integer, Integer) -> void } -> void
    def self.each_descendant(data, start, finish, containers, &block)
      each_box(data, start, finish) do |type, off, size, hdr|
        block.call(type, off, size, hdr)
        each_descendant(data, off + hdr, off + size, containers, &block) if containers.include?(type)
      end
    end

    #: (String data, Integer offset) -> Integer
    def self.box_header_size(data, offset)
      u32(data, offset) == 1 ? 16 : HEADER_SIZE
    end

    #: (Integer value) -> Integer
    def self.clamp_uint16(value)
      value.clamp(0, 0xFFFF)
    end

    #: (String data, Integer offset) -> Integer
    def self.u32(data, offset)
      value = (data[offset, 4] || '').unpack1(UINT32)
      value.is_a?(Integer) ? value : 0
    end

    #: (String data, Integer offset) -> Integer
    def self.u64(data, offset)
      value = (data[offset, 8] || '').unpack1(UINT64)
      value.is_a?(Integer) ? value : 0
    end
  end
end
