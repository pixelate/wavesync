# frozen_string_literal: true

require 'fileutils'
require 'streamio-ffmpeg'

module Wavesync
  # Scans a source library and syncs audio files to a target device directory,
  # converting formats, sample rates, and embedding BPM metadata as needed.
  class Scanner
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @audio_files = find_audio_files
      @ui = Wavesync::UI.new
      FFMPEG.logger = Logger.new(File::NULL)
    end

    def sync(target_library_path, device)
      path_resolver = PathResolver.new(@source_library_path, target_library_path, device)
      @ui.sync_progress(0, @audio_files.size, device)
      @audio_files.each_with_index do |file, index|
        sync_file(file, path_resolver, device)
        @ui.sync_progress(index, @audio_files.size, device)
      end
      puts
    end

    private

    def sync_file(file, path_resolver, device)
      audio = Audio.new(file)
      @ui.bpm(audio.bpm)
      @ui.file_progress(file)
      target_path, synced = copy_or_convert(file, audio, path_resolver, device)
      write_acid_bpm(target_path, audio) if synced && needs_acid_bpm?(audio, device, target_path)
      @ui.skip unless synced
    end

    def copy_or_convert(file, audio, path_resolver, device)
      conversions = needed_conversions(file, audio, device)
      if conversions.values.any?
        [path_resolver.resolve(file, audio, target_file_type: conversions[:file_type]),
         convert_file(audio, file, path_resolver, conversions)]
      else
        copy_and_notify(audio, file, path_resolver)
      end
    end

    def copy_and_notify(audio, file, path_resolver)
      copied = copy_file(audio, file, path_resolver)
      @ui.copy(audio.sample_rate, audio.bit_depth, File.extname(file).delete_prefix('.'))
      [path_resolver.resolve(file, audio), copied]
    end

    def needed_conversions(file, audio, device)
      {
        file_type: device.target_file_type(file),
        sample_rate: device.target_sample_rate(audio.sample_rate),
        bit_depth: device.target_bit_depth(audio.bit_depth)
      }
    end

    def needs_acid_bpm?(audio, device, target_path)
      device.bpm_source == :acid_chunk && audio.bpm && target_path.extname.downcase == '.wav'
    end

    def write_acid_bpm(target_path, audio)
      temp_path = "#{target_path}.tmp"
      AcidChunk.write_bpm(target_path.to_s, temp_path, audio.bpm)
      FileUtils.mv(temp_path, target_path.to_s)
    end

    def find_audio_files
      Dir.glob(File.join(@source_library_path, '**', '*'))
         .select { |f| Wavesync::Audio::SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end

    def copy_file(audio, source_file_path, path_resolver)
      target_path = path_resolver.resolve(source_file_path, audio)
      path_resolver.find_files_to_cleanup(target_path, audio).each { |file| FileUtils.rm_f(file) }
      return false if target_path.exist?

      safe_copy(source_file_path, target_path)
      true
    end

    def safe_copy(source, target)
      FileUtils.install(source, target)
    rescue Errno::ENOENT
      puts 'Errno::ENOENT'
    end

    def convert_file(audio, source_file_path, path_resolver, conversions)
      target_path = path_resolver.resolve(source_file_path, audio, target_file_type: conversions[:file_type])
      path_resolver.find_files_to_cleanup(target_path, audio).each { |f| FileUtils.rm_f(f) }
      return false if target_path.exist?

      target_path.dirname.mkpath
      source_file_type = File.extname(source_file_path).delete_prefix('.')
      @ui.conversion_progress(audio.sample_rate, audio.bit_depth, source_file_type, conversions)
      perform_transcode(audio, target_path, conversions)
      true
    end

    def perform_transcode(audio, target_path, conversions)
      audio.transcode(target_path.to_s,
                      target_sample_rate: conversions[:sample_rate],
                      target_file_type: conversions[:file_type],
                      target_bit_depth: conversions[:bit_depth] || audio.bit_depth)
    end
  end
end
