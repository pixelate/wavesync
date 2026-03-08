# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require_relative 'test_case'
require_relative '../../lib/wavesync/set'

module Wavesync
  class SetTest < Wavesync::TestCase
    def setup
      @tmp = Dir.mktmpdir
      @library = File.join(@tmp, 'library')
      FileUtils.mkdir_p(@library)
    end

    def teardown
      FileUtils.rm_rf(@tmp)
    end

    test 'sets_path returns .sets inside the library' do
      assert_equal File.join(@library, '.sets'), Set.sets_path(@library)
    end

    test 'set_path returns yaml file inside .sets' do
      assert_equal File.join(@library, '.sets', 'my_set.yml'), Set.set_path(@library, 'my_set')
    end

    test 'exists? returns false when set file is absent' do
      refute Set.exists?(@library, 'missing')
    end

    test 'exists? returns true after a set is saved' do
      Set.new(@library, 'demo').save
      assert Set.exists?(@library, 'demo')
    end

    test 'new set has empty tracks by default' do
      assert_empty Set.new(@library, 'empty').tracks
    end

    test 'new set accepts an initial track list' do
      set = Set.new(@library, 'preloaded', ['/a.wav', '/b.wav'])
      assert_equal ['/a.wav', '/b.wav'], set.tracks
    end

    test 'tracks are independent from the array passed to initialize' do
      source = ['/a.wav']
      set = Set.new(@library, 's', source)
      source << '/b.wav'
      assert_equal ['/a.wav'], set.tracks
    end

    test 'add_track appends to the track list' do
      set = Set.new(@library, 's')
      set.add_track('/a.wav')
      set.add_track('/b.wav')
      assert_equal ['/a.wav', '/b.wav'], set.tracks
    end

    test 'remove_track deletes the track at the given index' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      set.remove_track(1)
      assert_equal ['/a.wav', '/c.wav'], set.tracks
    end

    test 'remove_track on the first element works' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav'])
      set.remove_track(0)
      assert_equal ['/b.wav'], set.tracks
    end

    test 'remove_track on the last element works' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav'])
      set.remove_track(1)
      assert_equal ['/a.wav'], set.tracks
    end

    test 'move_up swaps the track with the one above it' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      set.move_up(1)
      assert_equal ['/b.wav', '/a.wav', '/c.wav'], set.tracks
    end

    test 'move_up is a no-op at index 0' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav'])
      set.move_up(0)
      assert_equal ['/a.wav', '/b.wav'], set.tracks
    end

    test 'move_down swaps the track with the one below it' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      set.move_down(1)
      assert_equal ['/a.wav', '/c.wav', '/b.wav'], set.tracks
    end

    test 'move_down is a no-op at the last index' do
      set = Set.new(@library, 's', ['/a.wav', '/b.wav'])
      set.move_down(1)
      assert_equal ['/a.wav', '/b.wav'], set.tracks
    end

    test 'save creates the .sets directory if it does not exist' do
      Set.new(@library, 'fresh').save
      assert Dir.exist?(Set.sets_path(@library))
    end

    test 'save writes a yaml file with name and relative tracks' do
      tracks = [File.join(@library, 'a.wav'), File.join(@library, 'sub/b.wav')]
      Set.new(@library, 'my_set', tracks).save

      data = YAML.load_file(Set.set_path(@library, 'my_set'))
      assert_equal 'my_set', data['name']
      assert_equal %w[a.wav sub/b.wav], data['tracks']
    end

    test 'save persists an empty track list' do
      Set.new(@library, 'empty').save
      data = YAML.load_file(Set.set_path(@library, 'empty'))
      assert_equal [], data['tracks']
    end

    test 'load returns a Set with the persisted name and absolute tracks' do
      track = File.join(@library, 'x.wav')
      Set.new(@library, 'persisted', [track]).save
      loaded = Set.load(@library, 'persisted')
      assert_equal 'persisted', loaded.name
      assert_equal [track], loaded.tracks
    end

    test 'load raises when the set does not exist' do
      assert_raises(Errno::ENOENT) { Set.load(@library, 'ghost') }
    end

    test 'all returns empty array when .sets folder is absent' do
      assert_empty Set.all(@library)
    end

    test 'all returns all saved sets sorted by name' do
      Set.new(@library, 'zebra').save
      Set.new(@library, 'alpha').save
      Set.new(@library, 'mango').save

      names = Set.all(@library).map(&:name)
      assert_equal %w[alpha mango zebra], names
    end

    test 'all returns sets with their tracks as absolute paths' do
      tracks = [File.join(@library, 'a.wav'), File.join(@library, 'b.wav')]
      Set.new(@library, 'with_tracks', tracks).save
      loaded = Set.all(@library).first
      assert_equal tracks, loaded.tracks
    end
  end
end
