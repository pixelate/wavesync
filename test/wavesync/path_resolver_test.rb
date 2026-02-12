# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/path_resolver'

module Wavesync
  class PathResolverTest < Wavesync::TestCase
    def setup
      @source_library = '/home/user/music'
      @target_library = '/media/device/music'
      @resolver = PathResolver.new(@source_library, @target_library)
    end

    test 'resolve returns correct target path with same file type' do
      source_file = '/home/user/music/artist/album/song.wav'
      target_path = @resolver.resolve(source_file)

      assert_equal '/media/device/music/artist/album/song.wav', target_path.to_s
    end

    test 'resolve changes file extension when target_file_type provided' do
      source_file = '/home/user/music/artist/album/song.m4a'
      target_path = @resolver.resolve(source_file, target_file_type: 'wav')

      assert_equal '/media/device/music/artist/album/song.wav', target_path.to_s
    end

    test 'resolve handles complex paths with spaces and special characters' do
      source_file = '/home/user/music/electronic/aphex twin/selected ambient works/xtal.aiff'
      target_path = @resolver.resolve(source_file, target_file_type: 'wav')

      assert_equal '/media/device/music/electronic/aphex twin/selected ambient works/xtal.wav',
                   target_path.to_s
    end

    test 'resolve returns Pathname object' do
      source_file = '/home/user/music/artist/song.wav'
      target_path = @resolver.resolve(source_file)

      assert_instance_of Pathname, target_path
    end

    test 'handles source library without trailing slash' do
      resolver = PathResolver.new('/home/user/music', '/media/device')
      source_file = '/home/user/music/artist/song.wav'
      target_path = resolver.resolve(source_file)

      assert_equal '/media/device/artist/song.wav', target_path.to_s
    end

    test 'handles source library with trailing slash' do
      resolver = PathResolver.new('/home/user/music/', '/media/device/')
      source_file = '/home/user/music/artist/song.wav'
      target_path = resolver.resolve(source_file)

      assert_equal '/media/device/artist/song.wav', target_path.to_s
    end
  end
end
