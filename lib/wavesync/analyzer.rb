# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  class Analyzer
    CONFIRM_MESSAGE = 'wavesync analyze will add bpm meta data to files in library. Continue? [y/N] '
    SETUP_INSTRUCTIONS = 'brew install python@3.11 && python3.11 -m venv ~/.wavesync-venv && ~/.wavesync-venv/bin/pip install essentia'

    #: (String library_path) -> void
    def initialize(library_path)
      @library_path = File.expand_path(library_path) #: String
      @audio_files = find_audio_files #: Array[String]
      @ui = UI.new #: UI
    end

    #: (?overwrite: bool) -> void
    def analyze(overwrite: false)
      unless BpmDetector.available?
        puts "Error: essentia is not installed. Set up the Python venv with:\n  #{SETUP_INSTRUCTIONS}"
        exit 1
      end

      return unless @ui.confirm(CONFIRM_MESSAGE)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)

        if audio.bpm && !overwrite
          @ui.analyze_progress(index, @audio_files.size)
          @ui.analyze_skip(file, audio.bpm)
          next
        end

        bpm = BpmDetector.detect(file)
        audio.write_bpm(bpm) if bpm
        @ui.analyze_progress(index, @audio_files.size)
        @ui.analyze_result(file, bpm)
      end
    end

    private

    #: () -> Array[String]
    def find_audio_files
      Audio.find_all(@library_path).sort
    end
  end
end
