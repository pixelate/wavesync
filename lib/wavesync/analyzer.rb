# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'logger'

module Wavesync
  class Analyzer
    SETUP_INSTRUCTIONS = 'brew install python@3.11 && python3.11 -m venv ~/.wavesync-venv && ~/.wavesync-venv/bin/pip install essentia'

    #: (String library_path) -> void
    def initialize(library_path)
      @library_path = File.expand_path(library_path) #: String
      Logger.configure(@library_path)
      @audio_files = find_audio_files #: Array[String]
      @ui = UI.new #: UI
    end

    #: (?overwrite: bool, ?path: String?) -> void
    def analyze(overwrite: false, path: nil)
      unless BpmDetector.available?
        puts "Error: essentia is not installed. Set up the Python venv with:\n  #{SETUP_INSTRUCTIONS}"
        exit 1
      end

      files = files_for(path)
      return unless @ui.confirm(confirm_message(path))

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      files.each_with_index do |file, index|
        audio = Audio.new(file)

        if audio.bpm && !overwrite
          @ui.analyze_progress(index, files.size)
          @ui.analyze_skip(file, audio.bpm)
          next
        end

        bpm = BpmDetector.detect(file)
        audio.write_bpm(bpm) if bpm
        @ui.analyze_progress(index, files.size)
        @ui.analyze_result(file, bpm)
      end

      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      Logger.log_run_time(elapsed)
    end

    private

    #: (String? path) -> String
    def confirm_message(path)
      target =
        if path.nil?
          'files in library'
        elsif File.directory?(File.expand_path(path))
          'files in folder'
        else
          'file'
        end

      "wavesync analyze will add bpm meta data to #{target}. Continue? [y/N] "
    end

    #: (String? path) -> Array[String]
    def files_for(path)
      return @audio_files unless path

      expanded_path = File.expand_path(path)
      File.directory?(expanded_path) ? Audio.find_all(expanded_path) : [expanded_path]
    end

    #: () -> Array[String]
    def find_audio_files
      Audio.find_all(@library_path).sort
    end
  end
end
