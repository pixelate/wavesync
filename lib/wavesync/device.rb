# frozen_string_literal: true

require 'yaml'

module Wavesync
  class Device
    attr_reader :name, :sample_rates, :file_types

    def initialize(name:, sample_rates:, file_types:)
      @name = name
      @sample_rates = sample_rates
      @file_types = file_types
    end

    class << self
      attr_writer :config_path
    end

    def self.config_path
      @config_path ||= File.expand_path('../../config/devices.yml', __dir__)
    end

    def self.configure(path:)
      self.config_path = path
      @all = nil
    end

    def self.all
      @all ||= load_from_yaml
    end

    def self.find_by(name:)
      all.find { |device| device.name == name }
    end

    def self.load_from_yaml
      data = YAML.load_file(config_path)
      data.fetch('devices').map do |attrs|
        new(
          name: attrs['name'],
          sample_rates: attrs['sample_rates'],
          file_types: attrs['file_types']
        )
      end
    end
  end
end
