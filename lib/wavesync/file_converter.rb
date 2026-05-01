# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  class FileConverter
    DURATION_TOLERANCE_SECONDS = 0.5

    #: (Audio audio, String source_file_path, PathResolver path_resolver, AudioFormat source_format, AudioFormat target_format, ?padding_seconds: Numeric?, ?before_transcode: (^() -> void)?, ?metadata: Hash[String, String], ?mp3_bitrate: Integer) ?{ (String) -> void } -> bool
    def convert(audio, source_file_path, path_resolver, source_format, target_format, padding_seconds: nil, before_transcode: nil, metadata: {}, mp3_bitrate: 192, &post_transcode)
      needs_format_conversion = target_format.file_type || target_format.sample_rate || target_format.bit_depth
      return false unless needs_format_conversion || padding_seconds&.positive?

      target_path = path_resolver.resolve(source_file_path, audio, target_file_type: target_format.file_type)

      files_to_cleanup = path_resolver.find_files_to_cleanup(target_path, audio)
      files_to_cleanup.each { |file| FileUtils.rm_f(file) }

      if target_format.file_type
        source_converted_path = Pathname(source_file_path).sub_ext(".#{target_format.file_type}")
        return false if source_converted_path.exist?
      end

      if target_path.exist?
        existing_duration = Audio.new(target_path.to_s).duration
        expected_duration = audio.duration + (padding_seconds || 0)
        return false if (existing_duration - expected_duration).abs < DURATION_TOLERANCE_SECONDS

        target_path.delete
      end

      target_path.dirname.mkpath
      before_transcode&.call

      audio.transcode(target_path.to_s, target_sample_rate: target_format.sample_rate,
                                        target_file_type: target_format.file_type,
                                        target_bit_depth: target_format.bit_depth || source_format.bit_depth,
                                        padding_seconds: padding_seconds,
                                        metadata: metadata,
                                        target_bitrate: mp3_bitrate,
                      &post_transcode)

      true
    end
  end
end
