# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Transport
    class Filesystem
      attr_reader :working_directory #: String

      #: ({ name: String, model: String, path: String, transport: String?, mp3_bitrate: Integer } device_config) -> void
      def initialize(device_config)
        @working_directory = device_config[:path]
      end

      #: () ?{ (Integer, Integer, String) -> void } -> void
      def prepare!
        # Filesystem destinations expose live device contents directly, so
        # there is nothing to pull beforehand.
      end

      #: () ?{ (Integer, Integer, String) -> void } -> void
      def commit!
        # Filesystem destinations are written to directly during sync, so there
        # is nothing to commit here.
      end

      #: () -> void
      def begin_push!; end

      #: (String relative_path) -> void
      def push_file!(relative_path); end

      #: () -> void
      def finish_push!; end
    end
  end
end
