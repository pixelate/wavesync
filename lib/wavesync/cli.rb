# frozen_string_literal: true

require 'optparse'

module Wavesync
  class CLI
    def self.start
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: wavesync [options]'

        opts.on('-c', '--config PATH', 'Path to wavesync config YAML file') do |v|
          options[:config] = v
        end
      end

      parser.parse!

      config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
      config = Wavesync::Config.load(config_path)

      scanner = Wavesync::Scanner.new(config.library)

      config.device_configs.each do |dc|
        device = Wavesync::Device.find_by(name: dc[:name])

        unless device
          puts "Device #{dc[:name]} is not supported."
          next
        end

        scanner.sync(dc[:path], device)
      end
    end
  end
end
