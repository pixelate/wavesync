# frozen_string_literal: true

target :wavesync do
  signature 'sig'

  check 'lib'

  # Ignore files whose bodies Steep cannot check due to DSL patterns
  ignore 'lib/wavesync/audio_format.rb'
  ignore 'lib/wavesync/libmtp.rb'

  library 'json'
  library 'logger'
  library 'yaml'
  library 'psych'
  library 'fileutils'
  library 'pathname'
  library 'shellwords'
  library 'open3'
  library 'securerandom'
  library 'tmpdir'
  library 'tempfile'
  library 'io-console'
  library 'optparse'
end
