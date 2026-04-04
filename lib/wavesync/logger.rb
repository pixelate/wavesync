# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Logger
    #: (String? library_path) -> void
    def self.configure(library_path)
      @log_path = library_path ? File.join(library_path, 'wavesync.log') : nil
    end

    #: () -> String?
    def self.log_path
      @log_path
    end

    #: (Array[String] args) -> void
    def self.capture_invocation(args)
      @invocation_args = args
    end

    #: () -> void
    def self.log_invocation
      path = log_path
      return unless path && @invocation_args

      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      invocation = (['wavesync'] + @invocation_args).join(' ')
      entry = "---\n[#{timestamp}] #{invocation}\n"
      File.open(path, 'a') { |file| file.write(entry) }
      @invocation_args = nil
    end

    #: (Exception error, call_site: String, arguments: Hash[Symbol, untyped]) -> void
    def self.log_error(error, call_site:, arguments: {})
      path = log_path
      return unless path

      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      args_str = arguments.map { |key, value| "#{key}: #{value.inspect}" }.join(', ')
      entry = "[#{timestamp}] #{call_site}(#{args_str}) raised #{error.class}: #{error.message}\n"
      File.open(path, 'a') { |file| file.write(entry) }
    end
  end
end
