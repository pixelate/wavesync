require 'wahwah'
require 'fileutils'
require 'pathname'

module Wavesync
  class Scanner
    SUPPORTED_FORMATS = %w[.mp3 .wav].freeze
  
    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @catalog = []
      @audio_files = find_audio_files
    end
  
    def sync(target_library_path, device)
      skipped_count = 0
      conversion_count = 0
  
      @audio_files.each_with_index do |file, index|
        requires_conversion = requires_conversion?(file, device)

        unless requires_conversion
          copied = copy_file(file, target_library_path)
        end
  
        skipped_count = skipped_count + 1 unless copied
        conversion_count = conversion_count + 1 if requires_conversion
        print "\rSyncing:  #{index + 1}/#{@audio_files.count} (#{skipped_count} skipped/#{conversion_count} require conversion)"
      end
  
      puts
    end
  
    private
  
    def find_audio_files
      Dir.glob(File.join(@source_library_path, '**', '*'))
        .select { |f| SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end
  
    def copy_file(source_file_path, target_library_path)
      relative_source_path_name = Pathname(source_file_path).relative_path_from(@source_library_path)
      target_libary_path_name = Pathname(File.expand_path(target_library_path))
      target_path = target_libary_path_name.join(relative_source_path_name)
  
      if target_path.exist?
        false
      else
        FileUtils.install(source_file_path, target_path) unless target_path.exist?
        true
      end
    end

    def requires_conversion?(source_file_path, device)
      tag = WahWah.open(source_file_path)

      file_extension = File.extname(source_file_path).downcase[1..]

      return true unless device.file_types.include?(file_extension)
      return true unless device.sample_rates.include?(tag.sample_rate)

      false
    end
  end
end
