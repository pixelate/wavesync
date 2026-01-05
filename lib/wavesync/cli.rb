require "optparse"

module Wavesync
  class CLI
    def self.start
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: wavesync [options]"

        opts.on("-s", "--source PATH", "Source music library") do |v|
          options[:source] = v
        end

        opts.on("-t", "--target PATH", "Target sync directory") do |v|
          options[:target] = v
        end

        opts.on("-d", "--device DEVICE_MODEL", "Target device model (Octatrack or TP-7)") do |v|
          options[:device] = v
        end
      end

      parser.parse!

      unless options[:source] && options[:target] && options[:device]
        puts parser
        exit 1
      end

      device = Wavesync::Device.find_by(name: options[:device])
      
      unless device
        puts "Device #{options[:device]} does not exist."
        exit 1
      end

      scanner = Wavesync::Scanner.new(options[:source])
      scanner.sync(options[:target], device)
    end
  end
end
