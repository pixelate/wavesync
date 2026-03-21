# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Wavesync
  module PythonVenv
    PYTHON_PATH = File.expand_path('~/.wavesync-venv/bin/python3').freeze

    #: () -> bool
    def self.available?
      File.executable?(PYTHON_PATH)
    end

    #: () -> bool?
    def self.essentia_available?
      available? && system("#{PYTHON_PATH} -c 'import essentia' > /dev/null 2>&1")
    end

    #: (String script, String file_path) -> String
    def self.run_script(script, file_path)
      `#{PYTHON_PATH} -c #{Shellwords.escape(script)} #{Shellwords.escape(file_path)} 2>/dev/null`
    end
  end
end
