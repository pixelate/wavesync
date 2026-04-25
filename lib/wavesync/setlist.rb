# frozen_string_literal: true
# rbs_inline: enabled

require 'yaml'
require 'fileutils'

module Wavesync
  class Setlist
    SETLISTS_FOLDER = '.setlists'

    attr_reader :name #: String
    attr_reader :tracks #: Array[String]
    attr_reader :library_path #: String

    #: (String library_path) -> String
    def self.setlists_path(library_path)
      File.join(library_path, SETLISTS_FOLDER)
    end

    #: (String library_path, String name) -> String
    def self.setlist_path(library_path, name)
      File.join(setlists_path(library_path), "#{name}.yml")
    end

    #: (String library_path, String name) -> Setlist
    def self.load(library_path, name)
      data = YAML.load_file(setlist_path(library_path, name))
      new(library_path, data['name'], expand_tracks(library_path, data['tracks']))
    end

    #: (String library_path) -> Array[Setlist]
    def self.all(library_path)
      path = setlists_path(library_path)
      return [] unless Dir.exist?(path)

      Dir.glob(File.join(path, '*.yml')).map do |file|
        data = YAML.load_file(file)
        new(library_path, data['name'], expand_tracks(library_path, data['tracks']))
      end.sort_by(&:name)
    end

    #: (String library_path, String name) -> bool
    def self.exists?(library_path, name)
      File.exist?(setlist_path(library_path, name))
    end

    #: (String library_path, String name, ?Array[String] tracks) -> void
    def initialize(library_path, name, tracks = [])
      @library_path = library_path
      @name = name
      @tracks = tracks.dup
    end

    #: (String path) -> void
    def add_track(path)
      @tracks << path
    end

    #: (Integer index) -> String?
    def remove_track(index)
      @tracks.delete_at(index)
    end

    #: (Integer index) -> void
    def move_up(index)
      return if index <= 0

      @tracks[index], @tracks[index - 1] = @tracks[index - 1], @tracks[index]
    end

    #: (Integer index) -> void
    def move_down(index)
      return if index >= @tracks.size - 1

      @tracks[index], @tracks[index + 1] = @tracks[index + 1], @tracks[index]
    end

    #: () -> void
    def save
      FileUtils.mkdir_p(self.class.setlists_path(@library_path))
      File.write(self.class.setlist_path(@library_path, @name), to_yaml)
    end

    private

    #: (String library_path, Array[String]? tracks) -> Array[String]
    def self.expand_tracks(library_path, tracks)
      (tracks || []).map { |t| File.join(library_path, t) }
    end
    private_class_method :expand_tracks

    #: () -> String
    def to_yaml
      relative_tracks = @tracks.map { |t| t.sub("#{@library_path}/", '') }
      { 'name' => @name, 'tracks' => relative_tracks }.to_yaml
    end
  end
end
