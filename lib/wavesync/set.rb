# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Wavesync
  class Set
    SETS_FOLDER = '.sets'

    attr_reader :name, :tracks, :library_path

    def self.sets_path(library_path)
      File.join(library_path, SETS_FOLDER)
    end

    def self.set_path(library_path, name)
      File.join(sets_path(library_path), "#{name}.yml")
    end

    def self.load(library_path, name)
      data = YAML.load_file(set_path(library_path, name))
      new(library_path, data['name'], expand_tracks(library_path, data['tracks']))
    end

    def self.all(library_path)
      path = sets_path(library_path)
      return [] unless Dir.exist?(path)

      Dir.glob(File.join(path, '*.yml')).map do |file|
        data = YAML.load_file(file)
        new(library_path, data['name'], expand_tracks(library_path, data['tracks']))
      end.sort_by(&:name)
    end

    def self.exists?(library_path, name)
      File.exist?(set_path(library_path, name))
    end

    def initialize(library_path, name, tracks = [])
      @library_path = library_path
      @name = name
      @tracks = tracks.dup
    end

    def add_track(path)
      @tracks << path
    end

    def remove_track(index)
      @tracks.delete_at(index)
    end

    def move_up(index)
      return if index <= 0

      @tracks[index], @tracks[index - 1] = @tracks[index - 1], @tracks[index]
    end

    def move_down(index)
      return if index >= @tracks.size - 1

      @tracks[index], @tracks[index + 1] = @tracks[index + 1], @tracks[index]
    end

    def save
      FileUtils.mkdir_p(self.class.sets_path(@library_path))
      File.write(self.class.set_path(@library_path, @name), to_yaml)
    end

    private

    def self.expand_tracks(library_path, tracks)
      (tracks || []).map { |t| File.join(library_path, t) }
    end
    private_class_method :expand_tracks

    def to_yaml
      relative_tracks = @tracks.map { |t| t.sub("#{@library_path}/", '') }
      { 'name' => @name, 'tracks' => relative_tracks }.to_yaml
    end
  end
end
