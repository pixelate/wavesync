# frozen_string_literal: true

target :wavesync do
  signature 'sig'

  check 'lib'

  # Ignore files whose bodies Steep cannot check due to DSL patterns
  ignore 'lib/wavesync/audio_format.rb'

  library 'json'
  library 'logger'
  library 'yaml'
  library 'psych'
  library 'fileutils'
  library 'pathname'
  library 'shellwords'
  library 'securerandom'
  library 'tmpdir'
  library 'io-console'
  library 'optparse'
end
