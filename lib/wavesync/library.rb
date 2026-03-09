# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Wavesync
  class Library
    FILE_NAME = 'library.yml'

    def self.load(library_path)
      instance = new(library_path)
      instance.send(:load_from_disk)
      instance
    end

    def initialize(library_path)
      @library_path = library_path
      @tracks = {}
    end

    def update_track(relative_path, length:, bars:)
      @tracks[relative_path] = { 'path' => relative_path, 'length' => length, 'bars' => bars }
    end

    def save
      sorted_tracks = @tracks.values.sort_by { |t| t['path'] }
      File.write(file_path, { 'tracks' => sorted_tracks }.to_yaml)
    end

    private

    def file_path
      File.join(@library_path, FILE_NAME)
    end

    def load_from_disk
      return unless File.exist?(file_path)

      data = YAML.load_file(file_path)
      (data['tracks'] || []).each do |track|
        @tracks[track['path']] = track
      end
    end
  end
end
