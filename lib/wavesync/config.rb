# frozen_string_literal: true
# rbs_inline: enabled

require 'yaml'

module Wavesync
  class ConfigError < StandardError; end

  class Config
    DEFAULT_PATH = File.join(Dir.home, 'wavesync.yml')

    SUPPORTED_KEYS = %w[library devices].freeze
    DEVICE_SUPPORTED_KEYS = %w[name model path projects_path].freeze
    DEVICE_REQUIRED_KEYS = %w[name model path].freeze

    attr_reader :library #: String
    attr_reader :device_configs #: Array[{ name: String, model: String, path: String, projects_path: String? }]

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
        {
          name: device['name'],
          model: device['model'],
          path: File.expand_path(device['path']),
          projects_path: device['projects_path'] && File.expand_path(device['projects_path'])
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

      projects_path = device['projects_path']
      return unless projects_path
      raise ConfigError, "Device #{index + 1} 'projects_path' must be a string" unless projects_path.is_a?(String)
    end
  end
end
