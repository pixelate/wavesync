# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'streamio-ffmpeg'
require_relative 'file_converter'

module Wavesync
  class Scanner
    #: (String source_library_path) -> void
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path) #: String
      @audio_files = find_audio_files #: Array[String]
      @ui = Wavesync::UI.new #: UI
      @converter = FileConverter.new #: FileConverter
      FFMPEG.logger = Logger.new(File::NULL)
    end

    #: (String target_library_path, Device device, ?pad: bool) -> void
    def sync(target_library_path, device, pad: false)
      path_resolver = PathResolver.new(@source_library_path, target_library_path, device)
      skipped_count = 0
      conversion_count = 0
      @ui.sync_progress(0, @audio_files.size, device)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)

        source_format = audio.format
        target_format = device.target_format(source_format, file)

        padding_seconds = nil #: Numeric?
        original_bars = nil #: Integer?
        target_bars = nil #: Integer?
        if pad && device.bar_multiple
          padding_seconds = TrackPadding.compute(audio.duration, audio.bpm, device.bar_multiple)
          original_bars, target_bars = TrackPadding.bar_counts(audio.duration, audio.bpm, device.bar_multiple) unless padding_seconds.zero?
          padding_seconds = nil if padding_seconds.zero?
        end

        @ui.bpm(audio.bpm, original_bars: original_bars, target_bars: target_bars)
        @ui.file_progress(file)

        if target_format.file_type || target_format.sample_rate || target_format.bit_depth || padding_seconds
          converted = @converter.convert(audio, file, path_resolver, source_format, target_format,
                                         padding_seconds: padding_seconds) do
            @ui.conversion_progress(source_format, target_format)
          end
          target_path = path_resolver.resolve(file, audio, target_file_type: target_format.file_type)
        else
          copied = copy_file(audio, file, path_resolver)
          @ui.copy(source_format)
          target_path = path_resolver.resolve(file, audio)
        end

        bpm = audio.bpm
        if (copied || converted) && device.bpm_source == :acid_chunk && bpm && target_path.extname.downcase == '.wav'
          temp_path = "#{target_path}.tmp"
          AcidChunk.write_bpm(target_path.to_s, temp_path, bpm)
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

    #: () -> Array[String]
    def find_audio_files
      Audio.find_all(@source_library_path)
    end

    #: (Audio audio, String source_file_path, PathResolver path_resolver) -> bool
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

    #: (String source, Pathname target) -> void
    def safe_copy(source, target)
      FileUtils.install(source, target)
    rescue Errno::ENOENT
      puts 'Errno::ENOENT'
    end
  end
end
