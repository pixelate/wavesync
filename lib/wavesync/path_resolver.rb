# frozen_string_literal: true

module Wavesync
  class PathResolver
    def initialize(source_library_path, target_library_path, device)
      @source_library_path = Pathname(File.expand_path(source_library_path))
      @target_library_path = Pathname(File.expand_path(target_library_path))
      @device = device
    end

    def resolve(source_file_path, audio, target_file_type: nil)
      relative_path = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_path = @target_library_path.join(relative_path)

      target_path = target_path.sub_ext(".#{target_file_type}") if target_file_type

      target_path = add_bpm_to_filename(target_path, audio.bpm) if @device.bpm_source == :filename && audio.bpm

      target_path
    end

    def find_files_to_cleanup(target_path, audio)
      return [] unless @device.bpm_source == :filename && audio.bpm

      path_without_bpm = remove_bpm_from_filename(target_path)

      if path_without_bpm != target_path && path_without_bpm.exist?
        [path_without_bpm]
      else
        []
      end
    end

    private

    def add_bpm_to_filename(path, bpm)
      ext = path.extname
      basename = path.basename(ext).to_s

      basename = basename.gsub(/ \d+ bpm/, '')

      new_basename = "#{basename} #{bpm} bpm#{ext}"
      path.dirname.join(new_basename)
    end

    def remove_bpm_from_filename(path)
      ext = path.extname
      basename = path.basename(ext).to_s
      basename_without_bpm = basename.gsub(/ \d+ bpm/, '')

      path.dirname.join("#{basename_without_bpm}#{ext}")
    end
  end
end
