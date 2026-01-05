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
      name: "TP-7",
      sample_rates: [44100, 48000, 88200, 96000],
      file_types: %w[wav mp3]
    )

    OCTATRACK = new(
      name: "Octatrack",
      sample_rates: [44100],
      file_types: %w[wav aiff aif]
    )

    ALL = [
      TP7, OCTATRACK
    ]
  end
end
