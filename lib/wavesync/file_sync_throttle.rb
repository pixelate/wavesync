# frozen_string_literal: true
# rbs_inline: enabled

require 'shellwords'

module Wavesync
  class FileSyncThrottle
    POLL_INTERVAL_SECONDS = 1
    TIMEOUT_SECONDS = 300

    # Waits until Field Kit has opened and then closed the target file,
    # which indicates it has finished reading it for MTP transfer to the device.
    #: (Pathname target_path) -> void
    def wait_for_sync(target_path)
      deadline = Time.now + TIMEOUT_SECONDS

      while Time.now < deadline
        wait(POLL_INTERVAL_SECONDS) until file_open?(target_path) || Time.now >= deadline
        wait(POLL_INTERVAL_SECONDS) while file_open?(target_path) && Time.now < deadline
        return
      end
    end

    def wait(seconds)
      sleep(seconds)
    end

    private

    #: (Pathname path) -> bool
    def file_open?(path)
      output = `lsof -F p #{Shellwords.escape(path.to_s)} 2>/dev/null`
      !output.strip.empty?
    end
  end
end
