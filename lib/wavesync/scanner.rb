# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'pathname'
require 'tempfile'
require_relative 'logger'
require_relative 'file_converter'

module Wavesync
  class Scanner
    #: (String source_library_path) -> void
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path) #: String
      Logger.configure(@source_library_path)
      @audio_files = find_audio_files #: Array[String]
      @ui = Wavesync::UI.new #: UI
      @converter = FileConverter.new #: FileConverter
    end

    #: (String target_library_path, Device device, ?pad: bool, ?staged: bool, ?mp3_bitrate: Integer) ?{ (String) -> void } -> void
    def sync(target_library_path, device, pad: false, staged: false, mp3_bitrate: 192, &on_file_synced)
      Timing.reset
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      target_library_pathname = Pathname.new(target_library_path)
      path_resolver = PathResolver.new(@source_library_path, target_library_path, device)
      skipped_count = 0
      conversion_count = 0
      @ui.sync_progress(0, @audio_files.size, device)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)
        bpm = audio.bpm

        source_format = audio.format
        target_format = device.target_format(source_format, file)
        target_format = target_format.with(sample_rate: nil, bit_depth: nil) if source_format.file_type == 'mp3' && target_format.file_type.nil?

        padding_seconds = nil #: Numeric?
        original_bars = nil #: Integer?
        target_bars = nil #: Integer?
        if pad && device.bar_multiple
          padding_seconds = TrackPadding.compute(audio.duration, bpm, device.bar_multiple)
          original_bars, target_bars = TrackPadding.bar_counts(audio.duration, bpm, device.bar_multiple) unless padding_seconds.zero?
          padding_seconds = nil if padding_seconds.zero?
        end

        @ui.bpm(bpm, original_bars: original_bars, target_bars: target_bars)
        @ui.file_progress(file)

        if target_format.file_type || target_format.sample_rate || target_format.bit_depth || padding_seconds
          target_ext = target_format.file_type || source_format.file_type
          transliterated_metadata = {} #: Hash[String, String]
          transliterated_metadata = audio.transliterated_tag_changes if device.transliterate_metadata && target_ext == 'mp3'
          converted = @converter.convert(audio, file, path_resolver, source_format, target_format,
                                         padding_seconds: padding_seconds,
                                         metadata: transliterated_metadata,
                                         mp3_bitrate: mp3_bitrate,
                                         before_transcode: -> { @ui.conversion_progress(source_format, target_format, mp3_bitrate) }) do |local_temp_path|
            inject_acid_bpm(local_temp_path, bpm, device)
            inject_cue_points(local_temp_path, audio, source_format, target_format)
          end
          converted_target_path = path_resolver.resolve(file, audio, target_file_type: target_format.file_type)
          verify_written(converted_target_path, source: file) if converted
          final_target_path = converted_target_path
        else
          if device.bpm_source == :acid_chunk && bpm && File.extname(file).downcase == '.wav'
            target_path = path_resolver.resolve(file, audio)
            files_to_cleanup = path_resolver.find_files_to_cleanup(target_path, audio)
            files_to_cleanup.each { |cleanup_file| FileUtils.rm_f(cleanup_file) }
            if target_path.exist?
              copied = false
            else
              target_path.dirname.mkpath
              AcidChunk.write_bpm(file, target_path.to_s, bpm)
              verify_written(target_path, source: file)
              copied = true
            end
          else
            copied = copy_file(audio, file, path_resolver)
            target_path = path_resolver.resolve(file, audio)
            if copied
              verify_written(target_path, source: file)
              inject_transliterated_metadata(target_path.to_s, device)
            end
          end
          final_target_path = target_path
          @ui.copy(source_format)
        end

        if !copied && !converted
          skipped_count += 1
          @ui.skip(staged: staged)
        end

        conversion_count += 1 if converted
        @ui.sync_progress(index, @audio_files.size, device)

        if on_file_synced && final_target_path
          relative_path = final_target_path.relative_path_from(target_library_pathname).to_s
          on_file_synced.call(relative_path)
        end
      end

      puts
      Timing.current.measure(:filesystem) { system('sync') }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      Logger.log_run_time(elapsed, timings: Timing.current.totals)
    end

    #: (String target_library_path, Device device) -> void
    def pull_cue_points(target_library_path, device)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      path_resolver = PathResolver.new(@source_library_path, target_library_path, device)
      @ui.pull_progress(0, @audio_files.size, device)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)
        source_format = audio.format
        @ui.file_progress(file)

        if source_format.file_type == 'wav'
          target_format = device.target_format(source_format, file)
          target_path = path_resolver.resolve(file, audio, target_file_type: target_format.file_type)
          if target_path.extname.downcase == '.wav' && target_path.exist?
            target_cue_points = CueChunk.read(target_path.to_s)
            if target_cue_points.any?
              source_cue_points = audio.cue_points
              audio.write_cue_points(target_cue_points) unless CueChunk.same?(source_cue_points, target_cue_points)
            end
          end
        end

        @ui.pull_progress(index, @audio_files.size, device)
      end

      puts
      system('sync')
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      Logger.log_run_time(elapsed)
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

    #: (String path, Device device) -> void
    def inject_transliterated_metadata(path, device)
      return unless device.transliterate_metadata

      Audio.new(path).transliterate_tags
    end

    #: (String local_temp_path, (Integer | Float | String)? bpm, Device device) -> void
    def inject_acid_bpm(local_temp_path, bpm, device)
      return unless device.bpm_source == :acid_chunk && bpm && File.extname(local_temp_path).downcase == '.wav'

      AcidChunk.write_bpm_in_place(local_temp_path, bpm)
    end

    #: (String local_temp_path, Audio audio, AudioFormat source_format, AudioFormat target_format) -> void
    def inject_cue_points(local_temp_path, audio, source_format, target_format)
      return unless source_format.file_type == 'wav' && File.extname(local_temp_path).downcase == '.wav'

      source_cue_points = audio.cue_points
      return unless source_cue_points.any?

      rescaled_cue_points = rescale_cue_points(source_cue_points, audio.sample_rate, target_format.sample_rate || audio.sample_rate)
      CueChunk.append_to_file(local_temp_path, rescaled_cue_points)
    end

    #: (Array[{identifier: Integer, sample_offset: Integer, label: String?}] cue_points, Integer? source_sample_rate, Integer? target_sample_rate) -> Array[{identifier: Integer, sample_offset: Integer, label: String?}]
    def rescale_cue_points(cue_points, source_sample_rate, target_sample_rate)
      return cue_points if source_sample_rate == target_sample_rate || source_sample_rate.nil? || target_sample_rate.nil?

      cue_points.map do |cue_point|
        cue_point.merge(sample_offset: (cue_point[:sample_offset] * target_sample_rate / source_sample_rate.to_f).round) #: {identifier: Integer, sample_offset: Integer, label: String?}
      end
    end

    #: (String source, Pathname target) -> void
    def safe_copy(source, target)
      Timing.current.measure(:copy) { FileUtils.install(source, target) }
    rescue Errno::ENOENT => e
      Logger.log_error(e, call_site: 'Scanner#safe_copy', arguments: { source:, target: })
    end

    #: (Pathname target_path, source: String) -> void
    def verify_written(target_path, source:)
      return if target_path.exist?

      error = RuntimeError.new('target file missing after write')
      Logger.log_error(error, call_site: 'Scanner#verify_written', arguments: { source:, target: target_path.to_s })
    end
  end
end
