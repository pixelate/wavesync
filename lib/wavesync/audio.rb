# frozen_string_literal: true

require 'streamio-ffmpeg'
require 'securerandom'
require 'tmpdir'
require 'fileutils'
require 'taglib'

module Wavesync
  class Audio
    def initialize(file_path)
      @file_path = file_path
      @audio = FFMPEG::Movie.new(file_path)
      @bpm = read_bpm_from_tag(file_path)
    end

    def sample_rate
      @audio.audio_sample_rate
    end

    def bit_depth
      @bit_depth ||= calculate_bit_depth
    end

    attr_reader :bpm

    def transcode(target_path, target_sample_rate: nil, target_file_type: nil)
      options = build_transcode_options(target_sample_rate)
      ext = target_file_type || File.extname(@file_path).delete_prefix('.')

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

    def build_transcode_options(target_sample_rate)
      options = { custom: %w[-loglevel warning -nostats -hide_banner] }
      options[:audio_sample_rate] = target_sample_rate if target_sample_rate
      options
    end

    def read_bpm_from_tag(file_path)
      TagLib::MPEG::File.open(file_path) do |file|
        tag = file.id3v2_tag
        tag.frame_list('TBPM').first&.to_s
      end
    end
  end
end
