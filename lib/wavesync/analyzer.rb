# frozen_string_literal: true

module Wavesync
  class Analyzer
    def initialize(library_path)
      @library_path = File.expand_path(library_path)
      @audio_files = find_audio_files
      @ui = UI.new
    end

    def analyze(overwrite: false)
      unless BpmDetector.available?
        puts 'Error: bpm-tools or ffmpeg is not installed. Install with: brew install bpm-tools ffmpeg'
        exit 1
      end

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

    def find_audio_files
      Audio.find_all(@library_path).sort
    end
  end
end
