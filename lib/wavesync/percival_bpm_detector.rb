# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'logger'
require_relative 'python_venv'

module Wavesync
  class PercivalBpmDetector
    PYTHON_SCRIPT = <<~PYTHON
      import essentia.standard as es, sys
      audio = es.MonoLoader(filename=sys.argv[1], sampleRate=44100)()
      bpm = es.PercivalBpmEstimator()(audio)
      print(round(float(bpm)))
    PYTHON

    #: () -> bool?
    def self.available?
      PythonVenv.essentia_available?
    end

    #: (String file_path) -> Integer?
    def self.detect(file_path)
      output = PythonVenv.run_script(PYTHON_SCRIPT, file_path)
      bpm = output.strip.to_f
      bpm.positive? ? bpm.round : nil
    rescue StandardError => e
      Logger.log_error(e, call_site: 'PercivalBpmDetector.detect', arguments: { file_path: })
      nil
    end
  end
end
