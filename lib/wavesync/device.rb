# frozen_string_literal: true
# rbs_inline: enabled

require 'yaml'
module Wavesync
  class Device
    attr_reader :name #: String
    attr_reader :sample_rates #: Array[Integer]
    attr_reader :bit_depths #: Array[Integer]
    attr_reader :file_types #: Array[String]
    attr_reader :bpm_source #: Symbol?
    attr_reader :bar_multiple #: Integer?
    attr_reader :unsupported_characters #: Array[String]

    #: (name: String, sample_rates: Array[Integer], file_types: Array[String], ?bit_depths: Array[Integer], ?bpm_source: Symbol?, ?bar_multiple: Integer?, ?unsupported_characters: Array[String]) -> void
    def initialize(name:, sample_rates:, file_types:, bit_depths: [], bpm_source: nil, bar_multiple: nil, unsupported_characters: [])
      @name = name
      @sample_rates = sample_rates
      @bit_depths = bit_depths
      @file_types = file_types
      @bpm_source = bpm_source
      @bar_multiple = bar_multiple
      @unsupported_characters = unsupported_characters
    end

    #: () -> String
    def self.config_path
      File.expand_path('../../config/devices.yml', __dir__ || '')
    end

    #: () -> Array[Device]
    def self.all
      @all ||= load_from_yaml
    end

    #: (name: String) -> Device?
    def self.find_by(name:)
      all.find { |device| device.name == name }
    end

    #: () -> Array[Device]
    def self.load_from_yaml
      data = YAML.load_file(config_path)
      data.fetch('devices').map do |attrs|
        new(
          name: attrs['name'],
          sample_rates: attrs['sample_rates'],
          bit_depths: attrs['bit_depths'] || [],
          file_types: attrs['file_types'],
          bpm_source: attrs['bpm_source']&.to_sym,
          bar_multiple: attrs['bar_multiple'],
          unsupported_characters: attrs['unsupported_characters'] || []
        )
      end
    end

    #: (AudioFormat source_format, String source_file_path) -> AudioFormat
    def target_format(source_format, source_file_path)
      AudioFormat.new(
        file_type: target_file_type(source_file_path),
        sample_rate: target_sample_rate(source_format.sample_rate),
        bit_depth: target_bit_depth(source_format.bit_depth)
      )
    end

    #: (String source_file_path) -> String?
    def target_file_type(source_file_path)
      file_extension = File.extname(source_file_path).downcase[1..] || ''
      return nil if file_types.include?(file_extension)

      file_types.first
    end

    #: (Integer? source_sample_rate) -> Integer?
    def target_sample_rate(source_sample_rate)
      return nil if source_sample_rate.nil?
      return nil if sample_rates.include?(source_sample_rate)

      sample_rates.min_by { |n| [(n - source_sample_rate).abs, -n] }
    end

    #: (Integer? source_bit_depth) -> Integer?
    def target_bit_depth(source_bit_depth)
      return nil if source_bit_depth.nil? || bit_depths.empty? || bit_depths.include?(source_bit_depth)

      bit_depths.min_by { |n| [(n - source_bit_depth).abs, -n] }
    end
  end
end
