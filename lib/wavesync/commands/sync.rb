# frozen_string_literal: true

require 'optparse'

module Wavesync
  module Commands
    class Sync < Command
      DEVICE_OPTION = Option.new(short: '-d', long: '--device NAME', description: 'Name of device to sync (as defined in config)')
      PAD_OPTION = Option.new(short: '-p', long: '--pad', description: 'Pad tracks with silence so total length is a multiple of 64 bars (Octatrack only)')

      self.name = 'sync'
      self.description = 'Sync music library to a device'
      self.options = [DEVICE_OPTION, PAD_OPTION].freeze

      def run
        options, config = parse_options(banner: 'Usage: wavesync sync [options]') do |opts, opts_hash|
          opts.on(*DEVICE_OPTION.to_a) { |value| opts_hash[:device] = value }
          opts.on(*PAD_OPTION.to_a) { opts_hash[:pad] = true }
        end

        device_configs = config.device_configs
        if options[:device]
          device_configs = device_configs.select { |device_config| device_config[:name] == options[:device] }
          if device_configs.empty?
            known = config.device_configs.map { |device_config| device_config[:name] }.join(', ')
            puts "Unknown device \"#{options[:device]}\". Devices in config: #{known}"
            exit 1
          end
        elsif device_configs.size > 1
          device_names = device_configs.map { |device_config| device_config[:name] }
          selected_name = Wavesync::UI.new.select('Select device', device_names)
          device_configs = device_configs.select { |device_config| device_config[:name] == selected_name }
        end

        device_pairs = device_configs.map do |device_config|
          device = Wavesync::Device.find_by(name: device_config[:model])
          unless device
            supported = Wavesync::Device.all.map(&:name).join(', ')
            puts "Unknown device model \"#{device_config[:model]}\" in config. Supported models: #{supported}"
            exit 1
          end
          [device_config, device]
        end

        scanner = Wavesync::Scanner.new(config.library)

        device_pairs.each do |device_config, device|
          scanner.sync(device_config[:path], device, pad: options[:pad] || false)
        end
      end
    end
  end
end
