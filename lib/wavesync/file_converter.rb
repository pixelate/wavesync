# frozen_string_literal: true

module Wavesync
  class FileConverter
    def convert(audio, source_file_path, path_resolver, target_file_type, _source_sample_rate,
                target_sample_rate, source_bit_depth, target_bit_depth, &before_transcode)
      return false unless target_file_type || target_sample_rate || target_bit_depth

      target_path = path_resolver.resolve(source_file_path, audio, target_file_type: target_file_type)

      files_to_cleanup = path_resolver.find_files_to_cleanup(target_path, audio)
      files_to_cleanup.each { |file| FileUtils.rm_f(file) }

      if target_file_type
        source_converted_path = Pathname(source_file_path).sub_ext(".#{target_file_type}")
        return false if source_converted_path.exist?
      end

      return false if target_path.exist?

      target_path.dirname.mkpath
      before_transcode&.call

      audio.transcode(target_path.to_s, target_sample_rate: target_sample_rate,
                                        target_file_type: target_file_type,
                                        target_bit_depth: target_bit_depth || source_bit_depth)

      true
    end
  end
end
