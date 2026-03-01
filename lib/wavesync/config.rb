# frozen_string_literal: true

require 'yaml'

module Wavesync
  class Config
    DEFAULT_PATH = File.join(Dir.home, 'wavesync.yml')

    attr_reader :library, :device_configs

    def self.load(path = DEFAULT_PATH)
      data = YAML.load_file(File.expand_path(path))
      new(data)
    end

    def initialize(data)
      @library = File.expand_path(data.fetch('library'))
      @device_configs = data.fetch('devices').map do |device|
        { name: device['name'], model: device['model'], path: File.expand_path(device['path']) }
      end
    end
  end
end
