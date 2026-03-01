# frozen_string_literal: true

require 'optparse'

module Wavesync
  class CLI
    def self.start
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: wavesync [options]'

        opts.on('-c', '--config PATH', 'Path to wavesync config YAML file') do |value|
          options[:config] = value
        end
      end

      parser.parse!

      config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
      config = Wavesync::Config.load(config_path)

      config.device_configs.each do |device_config|
        unless Wavesync::Device.find_by(name: device_config[:name])
          supported = Wavesync::Device.all.map(&:name).join(', ')
          puts "Unknown device \"#{device_config[:name]}\" in config. Supported devices: #{supported}"
          exit 1
        end
      end

      scanner = Wavesync::Scanner.new(config.library)

      config.device_configs.each do |device_config|
        scanner.sync(device_config[:path], Wavesync::Device.find_by(name: device_config[:name]))
      end
    end
  end
end
