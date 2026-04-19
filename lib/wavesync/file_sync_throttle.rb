# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Wavesync
  class FileSyncThrottle
    MODES = %i[file_size disk_space fixed_delay lsof].freeze

    POLL_INTERVAL_SECONDS = 1
    TIMEOUT_SECONDS = 300
    FREE_SPACE_THRESHOLD_BYTES = 500 * 1024 * 1024 # 500 MB
    FIXED_DELAY_SECONDS = 5

    #: (?mode: Symbol) -> void
    def initialize(mode: :file_size)
      @mode = mode
    end

    def mode
      @mode
    end

    #: (Pathname target_path) -> void
    def wait_for_sync(target_path)
      case @mode
      when :file_size then wait_for_file_size_stable(target_path)
      when :disk_space then wait_for_disk_space(target_path)
      when :fixed_delay then wait(FIXED_DELAY_SECONDS)
      when :lsof then wait_for_lsof(target_path)
      end
    end

    def wait(seconds)
      sleep(seconds)
    end

    private

    #: (Pathname target_path) -> void
    def wait_for_file_size_stable(target_path)
      deadline = Time.now + TIMEOUT_SECONDS
      previous_size = nil

      while Time.now < deadline
        return unless File.exist?(target_path.to_s)

        current_size = File.size(target_path.to_s)
        return if current_size == previous_size

        previous_size = current_size
        wait(POLL_INTERVAL_SECONDS)
      end
    end

    #: (Pathname target_path) -> void
    def wait_for_disk_space(target_path)
      deadline = Time.now + TIMEOUT_SECONDS

      while Time.now < deadline
        return if free_space_bytes(target_path) >= FREE_SPACE_THRESHOLD_BYTES

        wait(POLL_INTERVAL_SECONDS)
      end
    end

    #: (Pathname target_path) -> void
    def wait_for_lsof(target_path)
      deadline = Time.now + TIMEOUT_SECONDS

      while Time.now < deadline
        wait(POLL_INTERVAL_SECONDS) until file_open?(target_path) || Time.now >= deadline
        wait(POLL_INTERVAL_SECONDS) while file_open?(target_path) && Time.now < deadline
        return
      end
    end

    #: (Pathname path) -> Integer
    def free_space_bytes(path)
      output = `df -Pk #{Shellwords.escape(path.to_s)} 2>/dev/null`
      fields = output.lines.last&.split
      return 0 unless fields && fields.size >= 4

      fields[3].to_i * 1024
    end

    #: (Pathname path) -> bool
    def file_open?(path)
      output = `lsof -F p #{Shellwords.escape(path.to_s)} 2>/dev/null`
      !output.strip.empty?
    end
  end
end
