# frozen_string_literal: true
# rbs_inline: enabled

require 'yaml'

module Wavesync
  class ConfigError < StandardError; end

  class Config
    DEFAULT_PATH = File.join(Dir.home, 'wavesync.yml')

    SUPPORTED_KEYS = %w[library devices].freeze
    DEVICE_SUPPORTED_KEYS = %w[name model path transport mp3_bitrate].freeze
    DEVICE_REQUIRED_KEYS = %w[name model path].freeze
    SUPPORTED_TRANSPORTS = %w[filesystem mtp].freeze
    SUPPORTED_MP3_BITRATES = [96, 128, 160, 192, 256, 320].freeze
    DEFAULT_MP3_BITRATE = 192

    attr_reader :library #: String
    attr_reader :device_configs #: Array[{ name: String, model: String, path: String, transport: String, mp3_bitrate: Integer }]

    #: (?String path) -> Config
    def self.load(path = DEFAULT_PATH)
      expanded = File.expand_path(path)
      begin
        data = YAML.load_file(expanded)
      rescue Errno::ENOENT
        raise ConfigError, "Config file not found: #{path}"
      rescue Psych::SyntaxError => e
        raise ConfigError, "Invalid YAML in config file: #{e.message}"
      end
      new(data)
    end

    #: (untyped data) -> void
    def initialize(data)
      validate!(data)
      @library = File.expand_path(data['library'])
      @device_configs = data['devices'].each_with_index.map do |device, i|
        validate_device!(device, i)
        transport = device['transport'] || 'filesystem'
        path = transport == 'filesystem' ? File.expand_path(device['path']) : device['path']
        {
          name: device['name'],
          model: device['model'],
          path: path,
          transport: transport,
          mp3_bitrate: device['mp3_bitrate'] || DEFAULT_MP3_BITRATE
        }
      end
    end

    private

    #: (untyped data) -> void
    def validate!(data)
      raise ConfigError, 'Config file must contain a YAML mapping' unless data.is_a?(Hash)

      unsupported = data.keys - SUPPORTED_KEYS
      raise ConfigError, "Unsupported config keys: #{unsupported.join(', ')}" if unsupported.any?

      %w[library devices].each do |key|
        raise ConfigError, "Missing required config key: '#{key}'" unless data.key?(key)
      end

      raise ConfigError, "'library' must be a string" unless data['library'].is_a?(String)
      raise ConfigError, "'devices' must be a list" unless data['devices'].is_a?(Array)
      raise ConfigError, "'devices' must contain at least one device" if data['devices'].empty?
    end

    #: (untyped device, Integer index) -> void
    def validate_device!(device, index)
      raise ConfigError, "Device #{index + 1} must be a YAML mapping" unless device.is_a?(Hash)

      unsupported = device.keys - DEVICE_SUPPORTED_KEYS
      raise ConfigError, "Unsupported keys in device #{index + 1}: #{unsupported.join(', ')}" if unsupported.any?

      DEVICE_REQUIRED_KEYS.each do |key|
        raise ConfigError, "Missing required key '#{key}' in device #{index + 1}" unless device.key?(key)
      end

      %w[name model path].each do |key|
        raise ConfigError, "Device #{index + 1} '#{key}' must be a string" unless device[key].is_a?(String)
      end

      validate_device_transport!(device, index)
      validate_device_mp3_bitrate!(device, index)
    end

    #: (Hash[String, untyped] device, Integer index) -> void
    def validate_device_transport!(device, index)
      return unless device.key?('transport')

      raise ConfigError, "Device #{index + 1} 'transport' must be a string" unless device['transport'].is_a?(String)
      return if SUPPORTED_TRANSPORTS.include?(device['transport'])

      raise ConfigError, "Device #{index + 1} 'transport' must be one of: #{SUPPORTED_TRANSPORTS.join(', ')}"
    end

    #: (Hash[String, untyped] device, Integer index) -> void
    def validate_device_mp3_bitrate!(device, index)
      return unless device.key?('mp3_bitrate')

      raise ConfigError, "Device #{index + 1} 'mp3_bitrate' must be an integer" unless device['mp3_bitrate'].is_a?(Integer)
      return if SUPPORTED_MP3_BITRATES.include?(device['mp3_bitrate'])

      raise ConfigError, "Device #{index + 1} 'mp3_bitrate' must be one of: #{SUPPORTED_MP3_BITRATES.join(', ')}"
    end
  end
end
