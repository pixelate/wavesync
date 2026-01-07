# frozen_string_literal: true

require 'wahwah'
require 'fileutils'
require 'streamio-ffmpeg'
require 'securerandom'
require 'tmpdir'

module Wavesync
  class Scanner
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav].freeze

    def initialize(source_library_path)
      @source_library_path = File.expand_path(source_library_path)
      @audio_files = find_audio_files

      FFMPEG.logger = Logger.new(File::NULL)
    end

    def sync(target_library_path, device)
      skipped_count = 0
      conversion_count = 0

      @audio_files.each_with_index do |file, index|
        file_type = target_file_type(file, device)
        sample_rate = target_sample_rate(file, device)

        if file_type || sample_rate
          converted = convert_file(file, target_library_path, file_type, sample_rate)
        else
          copied = copy_file(file, target_library_path)
        end

        skipped_count += 1 if !copied && !converted
        conversion_count += 1 if converted
        print "\rSyncing:  #{index + 1}/#{@audio_files.count} (#{skipped_count} skipped/#{conversion_count} converted)"
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
        safe_copy(source_file_path, target_path)
        true
      end
    end

    def safe_copy(source, target)
      FileUtils.install(source, target)
    rescue Errno::ENOENT
    end

    def target_file_type(source_file_path, device)
      file_extension = File.extname(source_file_path).downcase[1..]

      return nil if device.file_types.include?(file_extension)

      device.file_types.first
    end

    def target_sample_rate(source_file_path, device)
      tag = WahWah.open(source_file_path)

      return nil if device.sample_rates.include?(tag.sample_rate)

      device.sample_rates.min_by { |n| [(n - tag.sample_rate).abs, -n] }
    end

    def convert_file(source_file_path, target_library_path, target_file_type, target_sample_rate)
      audio = FFMPEG::Movie.new(source_file_path)

      if target_file_type || target_sample_rate
        relative_source_path_name = Pathname(source_file_path).relative_path_from(@source_library_path)
        target_library_path_name = Pathname(File.expand_path(target_library_path))
        target_path = target_library_path_name.join(relative_source_path_name)

        target_path = target_path.sub_ext(".#{target_file_type}") if target_file_type

        unless target_path.exist?
          options = { audio_sample_rate: target_sample_rate, custom: %w[-loglevel warning -nostats -hide_banner] }
          target_path.dirname.mkpath

          ext = target_file_type || File.extname(source_file_path).delete_prefix('.')

          temp_path = File.join(
            Dir.tmpdir,
            "wavesync_transcode_#{SecureRandom.hex}.#{ext}"
          )

          begin
            audio.transcode(temp_path, options)

            safe_copy(temp_path, target_path.to_s)

            return true
          ensure
            FileUtils.rm_f(temp_path)
          end
        end
      end

      false
    end
  end
end
