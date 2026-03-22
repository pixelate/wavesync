# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  class FileSyncThrottle
    DELAY_SECONDS = 5

    #: (Pathname target_path) -> void
    def wait_for_sync(target_path)
      wait(DELAY_SECONDS)
    end

    def wait(seconds)
      sleep(seconds)
    end
  end
end
