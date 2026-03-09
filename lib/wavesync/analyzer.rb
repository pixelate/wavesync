# frozen_string_literal: true

module Wavesync
  class Analyzer
    BEATS_PER_BAR = 4

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

      library = Library.load(@library_path)

      @audio_files.each_with_index do |file, index|
        audio = Audio.new(file)

        if audio.bpm && !overwrite
          @ui.analyze_progress(index, @audio_files.size)
          @ui.analyze_skip(file, audio.bpm)
          update_library(library, file, audio)
          next
        end

        bpm = BpmDetector.detect(file)
        audio.write_bpm(bpm) if bpm
        @ui.analyze_progress(index, @audio_files.size)
        @ui.analyze_result(file, bpm)
        update_library(library, file, audio) if bpm
      end

      library.save
    end

    private

    def find_audio_files
      Audio.find_all(@library_path).sort
    end

    def update_library(library, file, audio)
      relative_path = file.sub("#{@library_path}/", '')
      bars = compute_bars(audio.duration, audio.bpm)
      library.update_track(relative_path, length: audio.length, bars: bars)
    end

    def compute_bars(duration_seconds, bpm)
      return nil unless duration_seconds && bpm && bpm.to_f.positive?

      (duration_seconds.to_f * bpm.to_f / (60.0 * BEATS_PER_BAR)).round
    end
  end
end
