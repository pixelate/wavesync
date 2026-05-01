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

    #: (Config config, ?device_name: String?) -> Array[untyped]
    def self.resolve_device_pairs(config, device_name: nil)
      device_configs = config.device_configs
      if device_name
        device_configs = device_configs.select { |device_config| device_config[:name] == device_name }
        if device_configs.empty?
          known = config.device_configs.map { |device_config| device_config[:name] }.join(', ')
          puts "Unknown device \"#{device_name}\". Devices in config: #{known}"
          exit 1
        end
      elsif device_configs.size > 1
        device_names = device_configs.map { |device_config| device_config[:name] }
        selected_name = Wavesync::UI.new.select('Select device', device_names)
        device_configs = device_configs.select { |device_config| device_config[:name] == selected_name }
      end

      device_configs.map do |device_config|
        device = Wavesync::Device.find_by(name: device_config[:model])
        unless device
          supported = Wavesync::Device.all.map(&:name).join(', ')
          puts "Unknown device model \"#{device_config[:model]}\" in config. Supported models: #{supported}"
          exit 1
        end
        [device_config, device]
      end
    end

    #: ((Wavesync::Transport::Filesystem | Wavesync::Transport::Mtp) transport, String device_name) { () -> void } -> void
    def self.with_mtp_retry(transport, device_name, &block)
      return block.call unless transport.is_a?(Wavesync::Transport::Mtp)

      begin
        block.call
      rescue Wavesync::Libmtp::Error => e
        puts "Could not reach #{device_name} over MTP (#{e.message}). Put the device in MTP mode, then press Enter to retry (Ctrl+C to abort)."
        $stdin.gets
        retry
      end
    end

    require_relative 'commands/command'
    require_relative 'commands/sync'
    require_relative 'commands/pull'
    require_relative 'commands/analyze'
    require_relative 'commands/setlist'
    require_relative 'commands/clear_cache'
    require_relative 'commands/help'

    ALL = [Sync, Pull, Analyze, Setlist, ClearCache, Help].freeze
  end
end
