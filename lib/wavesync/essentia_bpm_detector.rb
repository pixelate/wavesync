# frozen_string_literal: true
# rbs_inline: enabled

require 'json'
require_relative 'logger'
require_relative 'python_venv'

module Wavesync
  class EssentiaBpmDetector
    PYTHON_SCRIPT = <<~PYTHON
      import essentia, essentia.streaming as ess, essentia.standard as es, json, sys
      pool = essentia.Pool()
      loader = ess.MonoLoader(filename=sys.argv[1], sampleRate=44100)
      rhythm = ess.RhythmDescriptors()
      loader.audio >> rhythm.signal
      rhythm.bpm >> (pool, 'bpm')
      rhythm.confidence >> (pool, 'confidence')
      essentia.run(loader)
      bpm = round(float(pool['bpm']))
      confidence = round(float(pool['confidence']), 2)
      first_downbeat_position = 0.0
      if bpm > 0:
          try:
              audio = es.MonoLoader(filename=sys.argv[1], sampleRate=44100)()
              _, ticks, _, _, _ = es.RhythmExtractor2013(method='multifeature')(audio)
              if len(ticks) >= 4:
                  downbeat_positions, _ = es.Downbeat()(audio, ticks, float(bpm))
                  if len(downbeat_positions) > 0:
                      first_downbeat_position = round(float(downbeat_positions[0]), 6)
          except Exception:
              pass
      print(json.dumps({'bpm': bpm, 'confidence': confidence, 'first_downbeat_position': first_downbeat_position}))
    PYTHON

    #: () -> bool?
    def self.available?
      PythonVenv.essentia_available?
    end

    #: (String file_path) -> {bpm: Integer, confidence: Float, first_downbeat_position: Float}?
    def self.detect(file_path)
      output = PythonVenv.run_script(PYTHON_SCRIPT, file_path)
      data = JSON.parse(output.strip)
      bpm = data['bpm'].to_f
<<<<<<< HEAD
      bpm.positive? ? { bpm: bpm.round, confidence: data['confidence'].to_f, first_downbeat_position: data['first_downbeat_position'].to_f } : nil
    rescue StandardError => e
      Logger.log_error(e, call_site: 'EssentiaBpmDetector.detect', arguments: { file_path: })
      nil
    end
  end
end
