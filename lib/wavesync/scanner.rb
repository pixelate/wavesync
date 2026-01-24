# frozen_string_literal: true

require 'fileutils'
require 'streamio-ffmpeg'

module Wavesync
  class Scanner
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav .aif .aiff].freeze

    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @audio_files = find_audio_files
      @ui = Wavesync::UI.new

      FFMPEG.logger = Logger.new(File::NULL)
    end

    def sync(target_library_path, device)
      skipped_count = 0
      conversion_count = 0

      @ui.sync_progress(0, @audio_files.size, device)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)
        @ui.bpm(audio.bpm)
        file_type = target_file_type(file, device)
        source_sample_rate = audio.sample_rate
        source_bit_depth = audio.bit_depth
        target_sample_rate = target_sample_rate(source_sample_rate, device)

        @ui.file_progress(file)

        if file_type || target_sample_rate
          converted = convert_file(audio, file, target_library_path, file_type, source_sample_rate,
                                   target_sample_rate, source_bit_depth)
        else
          copied = copy_file(file, target_library_path)
          source_file_type = File.extname(file).delete_prefix('.')
          @ui.copy(source_sample_rate, source_bit_depth, source_file_type)
        end

        if !copied && !converted
          skipped_count += 1
          @ui.skip
        end

        conversion_count += 1 if converted
        @ui.sync_progress(index, @audio_files.size, device)
      end

      puts
    end

    private

    def find_audio_files
      Dir.glob(File.join(@source_library_path, '**', '*'))
         .select { |f| SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end

    def copy_file(source_file_path, target_library_path)
      relative_source_path_name = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_libary_path_name = Pathname(File.expand_path(target_library_path))
      target_path = target_libary_path_name.join(relative_source_path_name)

      if target_path.exist?
        false
      else
        safe_copy(source_file_path, target_path)
        true
      end
    end

    def safe_copy(source, target)
      FileUtils.install(source, target)
    rescue Errno::ENOENT
      puts 'Errno::ENOENT'
    end

    def target_file_type(source_file_path, device)
      file_extension = File.extname(source_file_path).downcase[1..]

      return nil if device.file_types.include?(file_extension)

      device.file_types.first
    end

    def target_sample_rate(source_sample_rate, device)
      return nil if device.sample_rates.include?(source_sample_rate)

      device.sample_rates.min_by { |n| [(n - source_sample_rate).abs, -n] }
    end

    def convert_file(audio, source_file_path, target_library_path, target_file_type, source_sample_rate,
                     target_sample_rate, source_bit_depth)
      return false unless target_file_type || target_sample_rate

      relative_source_path_name = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_library_path_name = Pathname(File.expand_path(target_library_path))
      target_path = target_library_path_name.join(relative_source_path_name)

      target_path = target_path.sub_ext(".#{target_file_type}") if target_file_type

      return false if target_path.exist?

      target_path.dirname.mkpath

      source_file_type = File.extname(source_file_path).delete_prefix('.')

      @ui.conversion_progress(source_sample_rate, target_sample_rate, source_bit_depth, source_file_type,
                              target_file_type)

      audio.transcode(target_path.to_s, target_sample_rate: target_sample_rate,
                                        target_file_type: target_file_type)
    end
  end
end
