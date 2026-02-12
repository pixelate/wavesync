# frozen_string_literal: true

module Wavesync
  class PathResolver
    def initialize(source_library_path, target_library_path)
      @source_library_path = Pathname(File.expand_path(source_library_path))
      @target_library_path = Pathname(File.expand_path(target_library_path))
    end

    def resolve(source_file_path, target_file_type: nil)
      relative_path = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_path = @target_library_path.join(relative_path)

      target_path = target_path.sub_ext(".#{target_file_type}") if target_file_type

      target_path
    end
  end
end
