# frozen_string_literal: true
# rbs_inline: enabled

require 'securerandom'
require 'tmpdir'
require 'fileutils'
require_relative 'logger'

module Wavesync
  class Audio
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav .aif .aiff].freeze

    #: (String library_path) -> Array[String]
    def self.find_all(library_path)
      Dir.glob(File.join(library_path, '**', '*'))
         .select { |file| SUPPORTED_FORMATS.include?(File.extname(file).downcase) }
         .sort_by(&:downcase)
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

    FRAME_ID_TO_FFMPEG_KEY = {
      ID3V2_FRAME_TITLE => 'title',
      ID3V2_FRAME_ARTIST => 'artist',
      ID3V2_FRAME_ALBUM => 'album',
      ID3V2_FRAME_ALBUM_ARTIST => 'album_artist',
      ID3V2_FRAME_GENRE => 'genre',
      ID3V2_FRAME_COMPOSER => 'composer',
      ID3V2_FRAME_ENCODED_BY => 'encoded_by',
      ID3V2_FRAME_COMPILATION => 'compilation'
    }.freeze

    FFMPEG_KEY_TO_FRAME_ID = FRAME_ID_TO_FFMPEG_KEY.invert.freeze

    COMBINING_MARKS = /\p{Mn}/

    #: () -> Hash[String, String]
    def transliterated_tag_changes
      current_tags = @audio.tags
      changes = {} #: Hash[String, String]

      FRAME_ID_TO_FFMPEG_KEY.each_value do |ffmpeg_key|
        current_value = find_in_tags(current_tags, ffmpeg_key)
        next if current_value.nil?

        transliterated = transliterate(current_value)
        changes[ffmpeg_key] = transliterated if transliterated != current_value
      end

      changes
    end

    #: () -> void
    def transliterate_tags
      return unless @file_ext == '.mp3'

      changes = transliterated_tag_changes
      return if changes.empty?

      write_file_metadata(changes)
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

    #: (String target_path, ?target_sample_rate: Integer?, ?target_file_type: String?, ?target_bit_depth: Integer?, ?padding_seconds: Numeric?, ?metadata: Hash[String, String]) ?{ (String) -> void } -> bool
    def transcode(target_path, target_sample_rate: nil, target_file_type: nil, target_bit_depth: nil, padding_seconds: nil, metadata: {})
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
        metadata.each { |key, value| command.metadata(key, value) }
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
      value = find_in_tags(@audio.tags, 'BPM')
      return nil if value.nil?

      int_value = value.to_i
      int_value.zero? ? nil : int_value
    end

    #: () -> String?
    def bpm_from_mp3
      value = find_in_tags(@audio.tags, 'TBPM')
      value&.then { |v| v.empty? ? nil : v }
    end

    #: () -> (String | Integer)?
    def bpm_from_wav
      value = find_in_tags(@audio.tags, 'TBPM')
      return value if value && !value.empty?

      bpm_from_acid_chunk
    end

    #: () -> String?
    def bpm_from_aiff
      value = find_in_tags(@audio.tags, 'TBPM')
      value&.then { |v| v.empty? ? nil : v }
    end

    #: (Hash[String, String] tags, String key) -> String?
    def find_in_tags(tags, key)
      tags.find { |k, _| k.casecmp(key).zero? }&.last
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
      write_file_metadata('TBPM' => bpm.to_s)
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_m4a(bpm)
      write_file_metadata('BPM' => bpm.to_i.to_s)
    end

    #: (String | Integer | Float bpm) -> void
    def write_bpm_to_aiff(bpm)
      write_file_metadata('TBPM' => bpm.to_s)
    end

    #: (Hash[String, String] metadata_hash) -> void
    def write_file_metadata(metadata_hash)
      ext = File.extname(@file_path)
      temp_path = File.join(Dir.tmpdir, "wavesync_meta_#{SecureRandom.hex}#{ext}")
      command = FFMPEG.new.input(@file_path).copy_streams.map_metadata(0)
      command.movflags('+use_metadata_tags') if ext == '.m4a'
      command.write_id3v2(1) if %w[.aif .aiff].include?(ext)
      metadata_hash.each { |key, value| command.metadata(key, value) }
      command.run(temp_path)
      FileUtils.mv(temp_path, @file_path)
    ensure
      FileUtils.rm_f(temp_path)
    end

    #: (String string) -> String
    def transliterate(string)
      string
        .unicode_normalize(:nfd)
        .gsub(COMBINING_MARKS, '')
    end
  end
end
