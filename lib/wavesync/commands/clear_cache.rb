# frozen_string_literal: true
# rbs_inline: enabled

require 'fileutils'
require 'optparse'
require_relative '../transport'

module Wavesync
  module Commands
    class ClearCache < Command
      DEVICE_OPTION = Option.new(short: '-d', long: '--device NAME', description: 'Clear cache for a specific device only')

      self.name = 'clear-cache'
      self.description = 'Delete the on-disk staging cache used for MTP devices'
      self.options = [DEVICE_OPTION].freeze

      #: () -> void
      def run
        options, config = parse_options(banner: 'Usage: wavesync clear-cache [options]') do |opts, opts_hash|
          opts.on(*DEVICE_OPTION.to_a) { |value| opts_hash[:device] = value }
        end

        mtp_devices = config.device_configs.select { |device_config| device_config[:transport] == 'mtp' }
        if options[:device]
          mtp_devices = mtp_devices.select { |device_config| device_config[:name] == options[:device] }
          if mtp_devices.empty?
            puts "No MTP device named \"#{options[:device]}\" found in config."
            exit 1
          end
        end

        if mtp_devices.empty?
          puts 'No MTP devices configured.'
          return
        end

        mtp_devices.each { |device_config| clear_one(device_config[:name]) }
      end

      private

      #: (String device_name) -> void
      def clear_one(device_name)
        path = Wavesync::Transport::Mtp.cache_path(device_name)
        unless File.directory?(path)
          puts "No cache for #{device_name} at #{path}"
          return
        end

        size_bytes = directory_size(path)
        FileUtils.rm_rf(path)
        puts "Cleared #{path} (#{format_bytes(size_bytes)})"
      end

      #: (String path) -> Integer
      def directory_size(path)
        Dir.glob(File.join(path, '**', '*'))
           .reject { |entry| File.directory?(entry) }
           .sum { |entry| File.size(entry) }
      end

      #: (Integer bytes) -> String
      def format_bytes(bytes)
        units = %w[B KB MB GB TB]
        size = bytes.to_f
        unit_index = 0
        while size >= 1024 && unit_index < units.length - 1
          size /= 1024
          unit_index += 1
        end
        unit_index.zero? ? "#{bytes} #{units[unit_index]}" : format('%<size>.1f %<unit>s', size: size, unit: units[unit_index])
      end
    end
  end
end
