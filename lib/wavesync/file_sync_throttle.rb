# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Wavesync
  class FileSyncThrottle
    POLL_INTERVAL_SECONDS = 2
    TIMEOUT_SECONDS = 300
    FREE_SPACE_THRESHOLD_BYTES = 500 * 1024 * 1024 # 500 MB

    #: (Pathname target_path) -> void
    def wait_for_sync(target_path)
      deadline = Time.now + TIMEOUT_SECONDS

      while Time.now < deadline
        return if free_space_bytes(target_path) >= FREE_SPACE_THRESHOLD_BYTES

        wait(POLL_INTERVAL_SECONDS)
      end
    end

    def wait(seconds)
      sleep(seconds)
    end

    private

    #: (Pathname path) -> Integer
    def free_space_bytes(path)
      output = `df -Pk #{Shellwords.escape(path.to_s)} 2>/dev/null`
      fields = output.lines.last&.split
      return 0 unless fields && fields.size >= 4

      fields[3].to_i * 1024
    end
  end
end
