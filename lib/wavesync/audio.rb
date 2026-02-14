# frozen_string_literal: true

require 'streamio-ffmpeg'
require 'securerandom'
require 'tmpdir'
require 'fileutils'
require 'taglib'

module Wavesync
  class Audio
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav .aif .aiff].freeze

    def initialize(file_path)
      @file_path = file_path
      @file_ext = File.extname(@file_path)
      @audio = FFMPEG::Movie.new(file_path)
      @bpm = bpm_from_file
    end

    def sample_rate
      @audio.audio_sample_rate
    end

    def bit_depth
      @bit_depth ||= calculate_bit_depth
    end

    attr_reader :bpm

    def transcode(target_path, target_sample_rate: nil, target_file_type: nil, target_bit_depth: nil)
      options = build_transcode_options(target_sample_rate, target_bit_depth)
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

    def calculate_bit_depth
      data = @audio.metadata
      return nil unless data && data[:streams]

      audio_stream = data[:streams].find { |s| s[:codec_type] == 'audio' }
      return nil unless audio_stream

      bits_per_sample = audio_stream[:bits_per_sample]
      return bits_per_sample if bits_per_sample&.positive?

      nil
    end

    def build_transcode_options(target_sample_rate, target_bit_depth)
      options = { custom: %w[-loglevel warning -nostats -hide_banner] }

      if target_bit_depth == 24
        options[:audio_codec] = 'pcm_s24le'
      elsif target_bit_depth == 16
        options[:audio_codec] = 'pcm_s16le'
      end

      options[:audio_codec] = 'pcm_s24le'
      options[:audio_sample_rate] = target_sample_rate if target_sample_rate
      options
    end

    def bpm_from_file
      ext = @file_ext.downcase
      case ext
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

    def bpm_from_m4a
      TagLib::MP4::File.open(@file_path) do |file|
        tag = file.tag
        return bpm_from_item_map(tag) if tag
      end
    end

    def bpm_from_mp3
      TagLib::MPEG::File.open(@file_path) do |file|
        tag = file.id3v2_tag
        return bpm_from_frame_list(tag) if tag
      end
    end

    def bpm_from_wav
      TagLib::RIFF::WAV::File.open(@file_path) do |file|
        tag = file.id3v2_tag
        bpm_from_frame_list = bpm_from_frame_list(tag) if tag
        return bpm_from_frame_list if bpm_from_frame_list
      end

      bpm_from_acid_chunk
    end

    def bpm_from_aiff
      TagLib::RIFF::AIFF::File.open(@file_path) do |file|
        tag = file.tag
        return bpm_from_frame_list(tag) if tag
      end
    end

    def bpm_from_item_map(tag)
      tmpo = tag.item_map['tmpo']&.to_int
      tmpo&.zero? ? nil : tmpo
    end

    def bpm_from_frame_list(tag)
      tag.frame_list('TBPM').first&.to_s
    end

    def bpm_from_acid_chunk
      tmpo = Wavesync::AcidChunkReader.extract_bpm(@file_path).to_i
      tmpo&.zero? ? nil : tmpo
    end
  end
end
