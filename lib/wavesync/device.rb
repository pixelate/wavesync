# frozen_string_literal: true

require 'yaml'
module Wavesync
  class Device
    attr_reader :name, :sample_rates, :bit_depths, :file_types, :bpm_source

    def initialize(name:, sample_rates:, bit_depths:, file_types:, bpm_source: nil)
      @name = name
      @sample_rates = sample_rates
      @bit_depths = bit_depths
      @file_types = file_types
      @bpm_source = bpm_source
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
          bit_depths: attrs['bit_depths'],
          file_types: attrs['file_types'],
          bpm_source: attrs['bpm_source']&.to_sym
        )
      end
    end

    def target_file_type(source_file_path)
      file_extension = File.extname(source_file_path).downcase[1..]
      return nil if file_types.include?(file_extension)

      file_types.first
    end

    def target_sample_rate(source_sample_rate)
      return nil if sample_rates.include?(source_sample_rate)

      sample_rates.min_by { |n| [(n - source_sample_rate).abs, -n] }
    end

    def target_bit_depth(source_bit_depth)
      return nil if source_bit_depth.nil? || bit_depths.include?(source_bit_depth)

      bit_depths.min_by { |n| [(n - source_bit_depth).abs, -n] }
    end
  end
end
