# frozen_string_literal: true
# rbs_inline: enabled

require 'streamio-ffmpeg'
require 'securerandom'
require 'tmpdir'
require 'fileutils'
require 'taglib'

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
      @audio = FFMPEG::Movie.new(file_path) #: untyped
    end

    #: () -> Float
    def duration
      @audio.duration
    end

    #: () -> Integer?
    def sample_rate
      @sample_rate ||= @audio.audio_sample_rate
    end

    #: () -> Integer?
    def bit_depth
      @bit_depth ||= calculate_bit_depth
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
        bit_depth: bit_depth
      )
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

    #: (String target_path, ?target_sample_rate: Integer?, ?target_file_type: String?, ?target_bit_depth: Integer?, ?padding_seconds: Numeric?) -> bool
    def transcode(target_path, target_sample_rate: nil, target_file_type: nil, target_bit_depth: nil, padding_seconds: nil)
      options = build_transcode_options(target_sample_rate, target_bit_depth, padding_seconds)
      ext = target_file_type || @file_ext.delete_prefix('.')
      temp_path = File.join(
        Dir.tmpdir,
        "wavesync_transcode_#{SecureRandom.hex}.#{ext}"
      )

      begin
        @audio.transcode(temp_path, options)
        FileUtils.install(temp_path, target_path)
        true
      rescue Errno::ENOENT
        puts 'Errno::ENOENT'
        false
      ensure
        FileUtils.rm_f(temp_path)
      end
    end

    private

    #: () -> Integer?
    def calculate_bit_depth
      data = @audio.metadata
      return nil unless data && data[:streams]

      audio_stream = data[:streams].find { |s| s[:codec_type] == 'audio' }
      return nil unless audio_stream

      bits_per_sample = audio_stream[:bits_per_sample]
      return bits_per_sample if bits_per_sample&.positive?

      nil
    end

    #: (Integer? target_sample_rate, Integer? target_bit_depth, ?Numeric? padding_seconds) -> Hash[Symbol, untyped]
    def build_transcode_options(target_sample_rate, target_bit_depth, padding_seconds = nil)
      options = { custom: %w[-loglevel warning -nostats -hide_banner] } #: Hash[Symbol, untyped]

      if target_bit_depth == 24
        options[:audio_codec] = 'pcm_s24le'
      elsif target_bit_depth == 16
        options[:audio_codec] = 'pcm_s16le'
      end

      options[:audio_codec] = 'pcm_s24le'
      options[:audio_sample_rate] = target_sample_rate if target_sample_rate

      if padding_seconds&.positive?
        total_duration = @audio.duration + padding_seconds
        options[:custom] += ['-af', "apad=whole_dur=#{total_duration.round(6)}"]
      end

      options
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
  end
end
