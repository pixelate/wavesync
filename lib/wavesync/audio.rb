# frozen_string_literal: true
# rbs_inline: enabled

require 'securerandom'
require 'tmpdir'
require 'fileutils'
require 'taglib'
require_relative 'logger'

module Wavesync
  class Audio
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav .aif .aiff].freeze

    #: (String library_path) -> Array[String]
    def self.find_all(library_path)
      Dir.glob(File.join(library_path, '**', '*'))
         .select { |f| SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end

    #: (String file_path) -> void
    def initialize(file_path)
      @file_path = file_path #: String
      @file_ext = File.extname(@file_path).downcase #: String
      @audio = Wavesync::FFMPEG::Probe.new(file_path) #: Wavesync::FFMPEG::Probe
    end

    #: () -> Float
    def duration
      @audio.duration
    end

    #: () -> Integer?
    def sample_rate
      @sample_rate ||= @audio.sample_rate
    end

    #: () -> Integer?
    def bit_depth
      @bit_depth ||= @audio.bit_depth
    end

    #: () -> Integer?
    def bitrate
      @bitrate ||= @audio.bitrate
    end

    #: () -> (String | Integer)?
    def bpm
      return @bpm if defined?(@bpm)

      @bpm = bpm_from_file
    end

    #: () -> AudioFormat
    def format
      AudioFormat.new(
        file_type: @file_ext.delete_prefix('.'),
        sample_rate: sample_rate,
        bit_depth: bit_depth,
        bitrate: bitrate
      )
    end

    #: () -> Array[{identifier: Integer, sample_offset: Integer, label: String?}]
    def cue_points
      return [] unless @file_ext == '.wav'

      CueChunk.read(@file_path)
    end

    #: (Array[{identifier: Integer, sample_offset: Integer, label: String?}] cue_points) -> void
    def write_cue_points(cue_points)
      temp_path = "#{@file_path}.tmp"
      CueChunk.write(@file_path, temp_path, cue_points)
      FileUtils.mv(temp_path, @file_path)
    end

    ID3V2_FRAME_TITLE = 'TIT2'
    ID3V2_FRAME_ARTIST = 'TPE1'
    ID3V2_FRAME_ALBUM = 'TALB'
    ID3V2_FRAME_ALBUM_ARTIST = 'TPE2'
    ID3V2_FRAME_GENRE = 'TCON'
    ID3V2_FRAME_COMPOSER = 'TCOM'
    ID3V2_FRAME_ENCODED_BY = 'TENC'
    ID3V2_FRAME_COMPILATION = 'TCMP'

    COMBINING_MARKS = /\p{Mn}/

    TRANSLITERATE_FRAME_IDS = [
      ID3V2_FRAME_TITLE,
      ID3V2_FRAME_ARTIST,
      ID3V2_FRAME_ALBUM,
      ID3V2_FRAME_ALBUM_ARTIST,
      ID3V2_FRAME_GENRE,
      ID3V2_FRAME_COMPOSER,
      ID3V2_FRAME_ENCODED_BY,
      ID3V2_FRAME_COMPILATION
    ].freeze

    #: () -> void
    def transliterate_tags
      return unless @file_ext == '.mp3'

      TagLib::MPEG::File.open(@file_path) do |file|
        tag = file.id3v2_tag
        next if tag.nil?

        TRANSLITERATE_FRAME_IDS.each do |frame_id|
          tag.frame_list(frame_id).each do |frame|
            frame.text = transliterate(frame.to_string)
          end
        end

        file.save
      end
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm(bpm)
      case @file_ext
      when '.m4a'
        write_bpm_to_m4a(bpm)
      when '.mp3'
        write_bpm_to_mp3(bpm)
      when '.wav'
        write_bpm_to_wav(bpm)
      when '.aif', '.aiff'
        write_bpm_to_aiff(bpm)
      end
      @bpm = bpm
    end

    #: (String target_path, ?target_sample_rate: Integer?, ?target_file_type: String?, ?target_bit_depth: Integer?, ?padding_seconds: Numeric?) ?{ (String) -> void } -> bool
    def transcode(target_path, target_sample_rate: nil, target_file_type: nil, target_bit_depth: nil, padding_seconds: nil)
      ext = target_file_type || @file_ext.delete_prefix('.')
      temp_path = File.join(Dir.tmpdir, "wavesync_transcode_#{SecureRandom.hex}.#{ext}")

      begin
        command = Wavesync::FFMPEG.new.input(@file_path).audio_codec(transcode_codec(ext, target_bit_depth))
        command.audio_bitrate('192k') if ext == 'mp3'
        command.sample_rate(target_sample_rate) if target_sample_rate
        if padding_seconds&.positive?
          total_duration = @audio.duration + padding_seconds
          command.audio_filter("apad=whole_dur=#{total_duration.round(6)}")
        end
        command.run(temp_path)
        yield temp_path if block_given?
        FileUtils.install(temp_path, target_path)
        true
      rescue Errno::ENOENT => e
        Logger.log_error(e, call_site: 'Audio#transcode', arguments: { target_path:, target_sample_rate:, target_file_type:, target_bit_depth:, padding_seconds: })
        false
      ensure
        FileUtils.rm_f(temp_path)
      end
    end

    private

    #: (String target_file_type, Integer? target_bit_depth) -> String
    def transcode_codec(target_file_type, target_bit_depth)
      return 'libmp3lame' if target_file_type == 'mp3'

      target_bit_depth == 16 ? 'pcm_s16le' : 'pcm_s24le'
    end

    #: () -> (String | Integer)?
    def bpm_from_file
      case @file_ext
      when '.m4a'
        bpm_from_m4a
      when '.mp3'
        bpm_from_mp3
      when '.wav'
        bpm_from_wav
      when '.aif', '.aiff'
        bpm_from_aiff
      end
    end

    #: () -> Integer?
    def bpm_from_m4a
      TagLib::MP4::File.open(@file_path) do |file|
        tag = file.tag
        return bpm_from_item_map(tag) if tag
      end
    end

    #: () -> String?
    def bpm_from_mp3
      TagLib::MPEG::File.open(@file_path) do |file|
        tag = file.id3v2_tag
        return bpm_from_frame_list(tag) if tag
      end
    end

    #: () -> (String | Integer)?
    def bpm_from_wav
      TagLib::RIFF::WAV::File.open(@file_path) do |file|
        tag = file.id3v2_tag
        bpm_from_frame_list = bpm_from_frame_list(tag) if tag
        return bpm_from_frame_list if bpm_from_frame_list
      end

      bpm_from_acid_chunk
    end

    #: () -> String?
    def bpm_from_aiff
      TagLib::RIFF::AIFF::File.open(@file_path) do |file|
        tag = file.tag
        return bpm_from_frame_list(tag) if tag
      end
    end

    #: (untyped tag) -> Integer?
    def bpm_from_item_map(tag)
      tmpo = tag.item_map['tmpo']&.to_int
      tmpo&.zero? ? nil : tmpo
    end

    #: (untyped tag) -> String?
    def bpm_from_frame_list(tag)
      tag.frame_list('TBPM').first&.to_s
    end

    #: () -> Integer?
    def bpm_from_acid_chunk
      tmpo = Wavesync::AcidChunk.read_bpm(@file_path).to_i
      tmpo&.zero? ? nil : tmpo
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_wav(bpm)
      temp_path = "#{@file_path}.tmp"
      AcidChunk.write_bpm(@file_path, temp_path, bpm)
      FileUtils.mv(temp_path, @file_path)
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_mp3(bpm)
      TagLib::MPEG::File.open(@file_path) do |file|
        write_id3v2_bpm(file.id3v2_tag(true), bpm)
        file.save
      end
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_m4a(bpm)
      TagLib::MP4::File.open(@file_path) do |file|
        tag = file.tag
        tag.item_map.insert('tmpo', TagLib::MP4::Item.from_int(bpm.to_i))
        file.save
      end
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_aiff(bpm)
      TagLib::RIFF::AIFF::File.open(@file_path) do |file|
        write_id3v2_bpm(file.tag, bpm)
        file.save
      end
    end

    #: (untyped tag, String | Integer | Float bpm) -> void
    def write_id3v2_bpm(tag, bpm)
      tag.remove_frames('TBPM')
      frame = TagLib::ID3v2::TextIdentificationFrame.new('TBPM', TagLib::String::UTF8)
      frame.text = bpm.to_s
      tag.add_frame(frame)
    end

    #: (String string) -> String
    def transliterate(string)
      string
        .unicode_normalize(:nfd)
        .gsub(COMBINING_MARKS, '')
    end
  end
end
