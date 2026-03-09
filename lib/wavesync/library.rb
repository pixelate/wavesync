# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Wavesync
  class Library
    FILE_NAME = 'library.yml'

    def self.load(library_path)
      new(library_path, load_tracks(library_path))
    end

    def self.load_tracks(library_path)
      file = File.join(library_path, FILE_NAME)
      return {} unless File.exist?(file)

      data = YAML.load_file(file)
      (data['tracks'] || []).each_with_object({}) { |t, h| h[t['path']] = t }
    end
    private_class_method :load_tracks

    def initialize(library_path, tracks = {})
      @library_path = library_path
      @tracks = tracks
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
  end
end
