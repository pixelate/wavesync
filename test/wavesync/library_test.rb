# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/library'

module Wavesync
  class LibraryTest < Wavesync::TestCase
    def setup
      @tmpdir = Dir.mktmpdir
      @library = Library.new(@tmpdir)
    end

    def teardown
      FileUtils.rm_rf(@tmpdir)
    end

    test 'saves tracks to library.yml' do
      @library.update_track('Artist/Song.wav', length: '3:45', bars: 128)
      @library.save

      data = YAML.load_file(File.join(@tmpdir, 'library.yml'))
      assert_equal 1, data['tracks'].size
      assert_equal 'Artist/Song.wav', data['tracks'][0]['path']
      assert_equal '3:45', data['tracks'][0]['length']
      assert_equal 128, data['tracks'][0]['bars']
    end

    test 'saves multiple tracks sorted by path' do
      @library.update_track('B/Two.wav', length: '2:00', bars: 64)
      @library.update_track('A/One.wav', length: '4:00', bars: 128)
      @library.save

      data = YAML.load_file(File.join(@tmpdir, 'library.yml'))
      assert_equal 'A/One.wav', data['tracks'][0]['path']
      assert_equal 'B/Two.wav', data['tracks'][1]['path']
    end

    test 'loads existing library.yml' do
      File.write(File.join(@tmpdir, 'library.yml'), {
        'tracks' => [{ 'path' => 'Artist/Song.wav', 'length' => '3:45', 'bars' => 128 }]
      }.to_yaml)

      library = Library.load(@tmpdir)
      library.update_track('Artist/Song.wav', length: '3:45', bars: 128)
      library.save

      data = YAML.load_file(File.join(@tmpdir, 'library.yml'))
      assert_equal 1, data['tracks'].size
    end

    test 'handles missing library.yml gracefully' do
      library = Library.load(@tmpdir)
      library.update_track('Song.wav', length: '1:30', bars: 32)
      library.save

      assert File.exist?(File.join(@tmpdir, 'library.yml'))
    end
  end
end
