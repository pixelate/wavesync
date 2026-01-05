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
      end

      parser.parse!

      unless options[:source] && options[:target]
        puts parser
        exit 1
      end

      scanner = Wavesync::Scanner.new(options[:source])
      scanner.scan
      scanner.sync(options[:target])
    end
  end
end
