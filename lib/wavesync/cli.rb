# frozen_string_literal: true

require 'optparse'

module Wavesync
  # Command-line interface entry point for running a wavesync operation.
  class CLI
    class << self
      def start
        options = parse_options
        device = find_device(options[:device])
        Wavesync::Scanner.new(options[:source]).sync(options[:target], device)
      end

      private

      def parse_options
        options = {}
        parser = build_parser(options)
        parser.parse!
        validate_options(options, parser)
        options
      end

      def build_parser(options)
        OptionParser.new do |opts|
          opts.banner = 'Usage: wavesync [options]'
          opts.on('-s', '--source PATH', 'Source music library') { |v| options[:source] = v }
          opts.on('-t', '--target PATH', 'Target sync directory') { |v| options[:target] = v }
          opts.on('-d', '--device DEVICE_MODEL', 'Target device model (Octatrack or TP-7)') { |v| options[:device] = v }
          opts.on('-c', '--config PATH', 'Path to device config YAML file') { |v| options[:config] = v }
        end
      end

      def validate_options(options, parser)
        Wavesync::Device.configure(path: options[:config]) if options[:config]
        return if options[:source] && options[:target] && options[:device]

        puts parser
        exit 1
      end

      def find_device(name)
        device = Wavesync::Device.find_by(name: name)
        return device if device

        puts "Device #{name} does not exist."
        exit 1
      end
    end
  end
end
