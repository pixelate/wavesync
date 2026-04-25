# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require_relative 'test_case'
require_relative '../../lib/wavesync/setlist'

module Wavesync
  class SetlistTest < Wavesync::TestCase
    def setup
      @tmp = Dir.mktmpdir
      @library = File.join(@tmp, 'library')
      FileUtils.mkdir_p(@library)
    end

    def teardown
      FileUtils.rm_rf(@tmp)
    end

    test 'setlists_path returns .setlists inside the library' do
      assert_equal File.join(@library, '.setlists'), Setlist.setlists_path(@library)
    end

    test 'setlist_path returns yaml file inside .setlists' do
      assert_equal File.join(@library, '.setlists', 'my_set.yml'), Setlist.setlist_path(@library, 'my_set')
    end

    test 'exists? returns false when setlist file is absent' do
      refute Setlist.exists?(@library, 'missing')
    end

    test 'exists? returns true after a setlist is saved' do
      Setlist.new(@library, 'demo').save
      assert Setlist.exists?(@library, 'demo')
    end

    test 'new setlist has empty tracks by default' do
      assert_empty Setlist.new(@library, 'empty').tracks
    end

    test 'new setlist accepts an initial track list' do
      setlist = Setlist.new(@library, 'preloaded', ['/a.wav', '/b.wav'])
      assert_equal ['/a.wav', '/b.wav'], setlist.tracks
    end

    test 'tracks are independent from the array passed to initialize' do
      source = ['/a.wav']
      setlist = Setlist.new(@library, 's', source)
      source << '/b.wav'
      assert_equal ['/a.wav'], setlist.tracks
    end

    test 'add_track appends to the track list' do
      setlist = Setlist.new(@library, 's')
      setlist.add_track('/a.wav')
      setlist.add_track('/b.wav')
      assert_equal ['/a.wav', '/b.wav'], setlist.tracks
    end

    test 'remove_track deletes the track at the given index' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      setlist.remove_track(1)
      assert_equal ['/a.wav', '/c.wav'], setlist.tracks
    end

    test 'remove_track on the first element works' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav'])
      setlist.remove_track(0)
      assert_equal ['/b.wav'], setlist.tracks
    end

    test 'remove_track on the last element works' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav'])
      setlist.remove_track(1)
      assert_equal ['/a.wav'], setlist.tracks
    end

    test 'move_up swaps the track with the one above it' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      setlist.move_up(1)
      assert_equal ['/b.wav', '/a.wav', '/c.wav'], setlist.tracks
    end

    test 'move_up is a no-op at index 0' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav'])
      setlist.move_up(0)
      assert_equal ['/a.wav', '/b.wav'], setlist.tracks
    end

    test 'move_down swaps the track with the one below it' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav', '/c.wav'])
      setlist.move_down(1)
      assert_equal ['/a.wav', '/c.wav', '/b.wav'], setlist.tracks
    end

    test 'move_down is a no-op at the last index' do
      setlist = Setlist.new(@library, 's', ['/a.wav', '/b.wav'])
      setlist.move_down(1)
      assert_equal ['/a.wav', '/b.wav'], setlist.tracks
    end

    test 'save creates the .setlists directory if it does not exist' do
      Setlist.new(@library, 'fresh').save
      assert Dir.exist?(Setlist.setlists_path(@library))
    end

    test 'save writes a yaml file with name and relative tracks' do
      tracks = [File.join(@library, 'a.wav'), File.join(@library, 'sub/b.wav')]
      Setlist.new(@library, 'my_set', tracks).save

      data = YAML.load_file(Setlist.setlist_path(@library, 'my_set'))
      assert_equal 'my_set', data['name']
      assert_equal %w[a.wav sub/b.wav], data['tracks']
    end

    test 'save persists an empty track list' do
      Setlist.new(@library, 'empty').save
      data = YAML.load_file(Setlist.setlist_path(@library, 'empty'))
      assert_equal [], data['tracks']
    end

    test 'load returns a Setlist with the persisted name and absolute tracks' do
      track = File.join(@library, 'x.wav')
      Setlist.new(@library, 'persisted', [track]).save
      loaded = Setlist.load(@library, 'persisted')
      assert_equal 'persisted', loaded.name
      assert_equal [track], loaded.tracks
    end

    test 'load raises when the setlist does not exist' do
      assert_raises(Errno::ENOENT) { Setlist.load(@library, 'ghost') }
    end

    test 'all returns empty array when .setlists folder is absent' do
      assert_empty Setlist.all(@library)
    end

    test 'all returns all saved setlists sorted by name' do
      Setlist.new(@library, 'zebra').save
      Setlist.new(@library, 'alpha').save
      Setlist.new(@library, 'mango').save

      names = Setlist.all(@library).map(&:name)
      assert_equal %w[alpha mango zebra], names
    end

    test 'all returns setlists with their tracks as absolute paths' do
      tracks = [File.join(@library, 'a.wav'), File.join(@library, 'b.wav')]
      Setlist.new(@library, 'with_tracks', tracks).save
      loaded = Setlist.all(@library).first
      assert_equal tracks, loaded.tracks
    end
  end
end
