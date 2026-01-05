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
  
    def scan
      @audio_files.each_with_index do |file, index|
        print "\rScanning: #{index + 1}/#{@audio_files.count}"
        scan_file(file)
      end
  
      puts
    end
  
    def sync(target_library_path)
      skipped_count = 0
  
      @audio_files.each_with_index do |file, index|
        copied = copy_file(file, target_library_path)
  
        skipped_count = skipped_count + 1 unless copied
        print "\rCopying:  #{index + 1}/#{@audio_files.count} (#{skipped_count} skipped)"
      end
  
      puts
    end
  
    private
  
    def find_audio_files
      Dir.glob(File.join(@source_library_path, '**', '*'))
        .select { |f| SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end
  
    def scan_file(file_path)
      tag = WahWah.open(file_path)
  
      @catalog << {
        file_path: file_path,
        sample_rate: tag.sample_rate,
        format: File.extname(file_path)[1..-1].upcase
      }
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
  end
end

scanner = Wavesync::Scanner.new("~/Music/Library")
scanner.scan
scanner.sync("~/tmp")
