# frozen_string_literal: true

require 'fileutils'
require 'streamio-ffmpeg'

module Wavesync
  class Scanner
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @audio_files = find_audio_files
      @ui = Wavesync::UI.new
      FFMPEG.logger = Logger.new(File::NULL)
    end

    def sync(target_library_path, device)
      path_resolver = PathResolver.new(@source_library_path, target_library_path)
      skipped_count = 0
      conversion_count = 0
      @ui.sync_progress(0, @audio_files.size, device)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)
        @ui.bpm(audio.bpm)

        file_type = device.target_file_type(file)
        source_sample_rate = audio.sample_rate
        source_bit_depth = audio.bit_depth
        target_sample_rate = device.target_sample_rate(source_sample_rate)
        target_bit_depth = device.target_bit_depth(source_bit_depth)

        @ui.file_progress(file)

        if file_type || target_sample_rate || target_bit_depth
          converted = convert_file(audio, file, path_resolver, file_type, source_sample_rate,
                                   target_sample_rate, source_bit_depth, target_bit_depth)
        else
          copied = copy_file(file, path_resolver)
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
         .select { |f| Wavesync::Audio::SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end

    def copy_file(source_file_path, path_resolver)
      target_path = path_resolver.resolve(source_file_path)

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

    def convert_file(audio, source_file_path, path_resolver, target_file_type, source_sample_rate,
                     target_sample_rate, source_bit_depth, target_bit_depth)
      return false unless target_file_type || target_sample_rate || target_bit_depth

      target_path = path_resolver.resolve(source_file_path, target_file_type: target_file_type)

      return false if target_path.exist?

      target_path.dirname.mkpath
      source_file_type = File.extname(source_file_path).delete_prefix('.')
      @ui.conversion_progress(source_sample_rate, target_sample_rate, source_bit_depth, source_file_type,
                              target_file_type, target_bit_depth)

      audio.transcode(target_path.to_s, target_sample_rate: target_sample_rate,
                                        target_file_type: target_file_type,
                                        target_bit_depth: target_bit_depth || source_bit_depth)
    end
  end
end
