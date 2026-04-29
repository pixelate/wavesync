# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Commands
    Option = Struct.new(:short, :long, :description)
    Subcommand = Struct.new(:usage, :description)

    CONFIG_OPTION = Option.new(short: '-c', long: '--config PATH', description: 'Path to wavesync config YAML file')
    GLOBAL_OPTIONS = [CONFIG_OPTION].freeze

    #: (String path) -> Config
    def self.load_config(path)
      Wavesync::Config.load(path)
    rescue Wavesync::ConfigError => e
      puts "Configuration error: #{e.message}"
      exit 1
    end

    require_relative 'commands/command'
    require_relative 'commands/sync'
    require_relative 'commands/analyze'
    require_relative 'commands/setlist'
    require_relative 'commands/clear_cache'
    require_relative 'commands/help'

    ALL = [Sync, Analyze, Setlist, ClearCache, Help].freeze
  end
end
