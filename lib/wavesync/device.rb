# frozen_string_literal: true

module Wavesync
  class Device
    attr_reader :name, :sample_rates, :file_types

    def initialize(name:, sample_rates:, file_types:)
      @name = name
      @sample_rates = sample_rates
      @file_types = file_types
    end

    def self.find_by(name:)
      ALL.find do |device|
        name == device.name
      end
    end

    TP7 = new(
      name: 'TP-7',
      sample_rates: [44_100, 48_000, 88_200, 96_000],
      file_types: %w[wav mp3]
    )

    OCTATRACK = new(
      name: 'Octatrack',
      sample_rates: [44_100],
      file_types: %w[wav aiff aif]
    )

    ALL = [
      TP7, OCTATRACK
    ].freeze
  end
end
