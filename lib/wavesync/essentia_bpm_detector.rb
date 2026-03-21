# frozen_string_literal: true
# rbs_inline: enabled

require 'json'
require_relative 'python_venv'

module Wavesync
  class EssentiaBpmDetector
    PYTHON_SCRIPT = <<~PYTHON
      import essentia, essentia.streaming as ess, json, sys
      pool = essentia.Pool()
      loader = ess.MonoLoader(filename=sys.argv[1], sampleRate=44100)
      rhythm = ess.RhythmDescriptors()
      loader.audio >> rhythm.signal
      rhythm.bpm >> (pool, 'bpm')
      rhythm.confidence >> (pool, 'confidence')
      essentia.run(loader)
      print(json.dumps({'bpm': round(float(pool['bpm'])), 'confidence': round(float(pool['confidence']), 2)}))
    PYTHON

    #: () -> bool?
    def self.available?
      PythonVenv.essentia_available?
    end

    #: (String file_path) -> {bpm: Integer, confidence: Float}?
    def self.detect(file_path)
      output = PythonVenv.run_script(PYTHON_SCRIPT, file_path)
      data = JSON.parse(output.strip)
      bpm = data['bpm'].to_f
      bpm.positive? ? { bpm: bpm.round, confidence: data['confidence'].to_f } : nil
    rescue StandardError
      nil
    end
  end
end
