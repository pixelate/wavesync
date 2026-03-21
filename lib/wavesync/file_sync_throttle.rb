# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  class FileSyncThrottle
    POLL_INTERVAL_SECONDS = 1
    TIMEOUT_SECONDS = 300

    #: (Pathname target_path) -> void
    def wait_for_sync(target_path)
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

    def wait(seconds)
      sleep(seconds)
    end
  end
end
