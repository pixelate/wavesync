# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Logger
    #: (String? library_path) -> void
    def self.configure(library_path)
      @log_path = library_path ? File.join(library_path, 'wavesync.log') : nil
      @invocation_args = nil unless library_path
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

      invocation = (['wavesync'] + @invocation_args).join(' ')
      entry = "---\n[#{timestamp}] #{invocation}\n"
      File.open(path, 'a') { |file| file.write(entry) }
      @invocation_args = nil
    end

    #: (Exception error, call_site: String, arguments: Hash[Symbol, untyped]) -> void
    def self.log_error(error, call_site:, arguments: {})
      path = log_path
      return unless path

      args_str = arguments.map { |key, value| "#{key}: #{value.inspect}" }.join(', ')
      entry = "[#{timestamp}] #{call_site}(#{args_str}) raised #{error.class}: #{error.message}\n"
      File.open(path, 'a') { |file| file.write(entry) }
    end

    #: (String message) -> void
    def self.log_event(message)
      path = log_path
      return unless path

      entry = "[#{timestamp}] #{message}\n"
      File.open(path, 'a') { |file| file.write(entry) }
    end

    #: (Float seconds, ?timings: Hash[Symbol, Float]) -> void
    def self.log_run_time(seconds, timings: {})
      path = log_path
      return unless path

      entry = "[#{timestamp}] Run time: #{format_duration(seconds)}\n"
      entry += format_timings(seconds, timings) unless timings.empty?
      File.open(path, 'a') { |file| file.write(entry) }
    end

    #: () -> String
    def self.timestamp
      Time.now.strftime('%Y-%m-%d %H:%M:%S')
    end
    private_class_method :timestamp

    #: (Float seconds) -> String
    def self.format_duration(seconds)
      total_seconds = seconds.to_i
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      secs = total_seconds % 60

      if hours.positive?
        "#{hours}h #{minutes}m #{secs}s"
      elsif minutes.positive?
        "#{minutes}m #{secs}s"
      else
        "#{secs}s"
      end
    end
    private_class_method :format_duration

    #: (Float total_seconds, Hash[Symbol, Float] timings) -> String
    def self.format_timings(total_seconds, timings)
      tracked = timings.values.sum
      other = [total_seconds - tracked, 0.0].max
      rows = timings.merge(other: other).select { |_, value| value.positive? }
      label_width = rows.keys.map { |key| key.to_s.length }.max || 0
      rows.map do |bucket, seconds|
        percentage = total_seconds.positive? ? (seconds / total_seconds * 100) : 0.0
        format("  %-#{label_width}s  %6.1fs  %5.1f%%\n", bucket, seconds, percentage)
      end.join
    end
    private_class_method :format_timings
  end
end
