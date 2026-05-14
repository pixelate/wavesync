# frozen_string_literal: true
# rbs_inline: enabled

require 'pathname'

module Wavesync
  class PathResolver
    BPM_PATTERN = / \d+ bpm/

    #: (String source_library_path, String target_library_path, Device device) -> void
    def initialize(source_library_path, target_library_path, device)
      @source_library_path = Pathname(File.expand_path(source_library_path)) #: Pathname
      @target_library_path = Pathname(File.expand_path(target_library_path)) #: Pathname
      @device = device #: Device
    end

    #: (String source_file_path, Audio audio, ?target_file_type: String?) -> Pathname
    def resolve(source_file_path, audio, target_file_type: nil)
      relative_path = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_path = @target_library_path.join(relative_path)

      target_path = target_path.sub_ext(".#{target_file_type}") if target_file_type

      bpm = audio.bpm
      target_path = add_bpm_to_filename(target_path, bpm) if @device.bpm_source == :filename && bpm

      target_path = strip_unsupported_characters(target_path)
      uppercase_relative_path(target_path)
    end

    #: (Pathname target_path, Audio audio) -> Array[Pathname]
    def find_files_to_cleanup(target_path, audio)
      return [] unless @device.bpm_source == :filename && audio.bpm

      ext = target_path.extname
      basename = target_path.basename(ext).to_s.gsub(BPM_PATTERN, '')

      pattern = target_path.dirname.join("#{basename}{, * bpm}#{ext}")
      Dir.glob(pattern.to_s).map { |f| Pathname(f) }
                            .reject { |path| File.identical?(path.to_s, target_path.to_s) }
    end

    private

    #: (Pathname path, String | Integer bpm) -> Pathname
    def add_bpm_to_filename(path, bpm)
      ext = path.extname
      basename = path.basename(ext).to_s

      basename = basename.gsub(BPM_PATTERN, '')

      new_basename = "#{basename} #{bpm} bpm#{ext}"
      path.dirname.join(new_basename)
    end

    #: (Pathname path) -> Pathname
    def strip_unsupported_characters(path)
      return path if @device.unsupported_characters.empty?

      Pathname(path.to_s.delete(@device.unsupported_characters.join))
    end

    #: (Pathname path) -> Pathname
    def uppercase_relative_path(path)
      return path unless @device.uppercase_paths

      relative = path.relative_path_from(@target_library_path)
      uppercased = relative.each_filename.map(&:upcase).join('/')
      @target_library_path.join(uppercased)
    end

    #: (Pathname path) -> Pathname
    def remove_bpm_from_filename(path)
      ext = path.extname
      basename = path.basename(ext).to_s
      basename_without_bpm = basename.gsub(BPM_PATTERN, '')

      path.dirname.join("#{basename_without_bpm}#{ext}")
    end
  end
end
