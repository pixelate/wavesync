# frozen_string_literal: true

require 'fileutils'
require 'streamio-ffmpeg'
require_relative 'file_converter'

module Wavesync
  class Scanner
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @audio_files = find_audio_files
      @ui = Wavesync::UI.new
      @converter = FileConverter.new
      FFMPEG.logger = Logger.new(File::NULL)
    end

    def sync(target_library_path, device)
      path_resolver = PathResolver.new(@source_library_path, target_library_path, device)
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
          converted = @converter.convert(audio, file, path_resolver, file_type, source_sample_rate,
                                         target_sample_rate, source_bit_depth, target_bit_depth) do
            source_file_type = File.extname(file).delete_prefix('.')
            @ui.conversion_progress(source_sample_rate, target_sample_rate, source_bit_depth,
                                    source_file_type, file_type, target_bit_depth)
          end
          target_path = path_resolver.resolve(file, audio, target_file_type: file_type)
        else
          copied = copy_file(audio, file, path_resolver)
          source_file_type = File.extname(file).delete_prefix('.')
          @ui.copy(source_sample_rate, source_bit_depth, source_file_type)
          target_path = path_resolver.resolve(file, audio)
        end

        if (copied || converted) && device.bpm_source == :acid_chunk && audio.bpm && target_path.extname.downcase == '.wav'
          temp_path = "#{target_path}.tmp"
          AcidChunk.write_bpm(target_path.to_s, temp_path, audio.bpm)
          FileUtils.mv(temp_path, target_path.to_s)
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
      Audio.find_all(@source_library_path)
    end

    def copy_file(audio, source_file_path, path_resolver)
      target_path = path_resolver.resolve(source_file_path, audio)

      files_to_cleanup = path_resolver.find_files_to_cleanup(target_path, audio)
      files_to_cleanup.each { |file| FileUtils.rm_f(file) }

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
  end
end
