# frozen_string_literal: true

require 'optparse'

module Wavesync
  module Commands
    class Command
      class << self
        attr_accessor :name, :description
        attr_writer :options, :subcommands

        def options = @options || []
        def subcommands = @subcommands || []
      end

      def parse_options(banner:)
        options = {}
        OptionParser.new do |opts|
          opts.banner = banner
          opts.on(*CONFIG_OPTION.to_a) { |value| options[:config] = value }
          yield opts, options if block_given?
        end.parse!
        config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
        config = Commands.load_config(config_path)
        [options, config]
      end
    end
  end
end
