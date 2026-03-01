# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/path_resolver'
require_relative '../../lib/wavesync/device'
require_relative '../../lib/wavesync/audio'

module Wavesync
  class PathResolverTest < Wavesync::TestCase
    CONFIG_PATH = File.expand_path('../../config/devices.yml', __dir__)

    def setup
      Device.configure(path: CONFIG_PATH)
      @source_library = '/home/user/music'
      @target_library = '/media/device/music'
    end

    test 'resolve returns correct target path with same file type' do
      source_file = '/home/user/music/artist/album/song.wav'
      audio = stub(bpm: nil)
      target_path = resolver_for('TP-7').resolve(source_file, audio)

      assert_equal '/media/device/music/artist/album/song.wav', target_path.to_s
    end

    test 'resolve changes file extension when target_file_type provided' do
      source_file = '/home/user/music/artist/album/song.m4a'
      audio = stub(bpm: nil)
      target_path = resolver_for('TP-7').resolve(source_file, audio, target_file_type: 'wav')

      assert_equal '/media/device/music/artist/album/song.wav', target_path.to_s
    end

    test 'resolve handles complex paths with spaces and special characters' do
      source_file = '/home/user/music/electronic/aphex twin/selected ambient works/xtal.aiff'
      audio = stub(bpm: nil)
      target_path = resolver_for('TP-7').resolve(source_file, audio, target_file_type: 'wav')

      assert_equal '/media/device/music/electronic/aphex twin/selected ambient works/xtal.wav',
                   target_path.to_s
    end

    test 'resolve returns Pathname object' do
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: nil)
      target_path = resolver_for('TP-7').resolve(source_file, audio)

      assert_instance_of Pathname, target_path
    end

    test 'handles source library without trailing slash' do
      device = Device.find_by(name: 'TP-7')
      resolver = PathResolver.new('/home/user/music', '/media/device', device)
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: nil)
      target_path = resolver.resolve(source_file, audio)

      assert_equal '/media/device/artist/song.wav', target_path.to_s
    end

    test 'handles source library with trailing slash' do
      device = Device.find_by(name: 'TP-7')
      resolver = PathResolver.new('/home/user/music/', '/media/device/', device)
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: nil)
      target_path = resolver.resolve(source_file, audio)

      assert_equal '/media/device/artist/song.wav', target_path.to_s
    end

    test 'adds bpm to filename when device has bpm_source :filename' do
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: 140)
      target_path = resolver_for('Octatrack').resolve(source_file, audio)

      assert_equal '/media/device/music/artist/song 140 bpm.wav', target_path.to_s
    end

    test 'does not add bpm to filename when device has no bpm_source' do
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: 140)
      target_path = resolver_for('TP-7').resolve(source_file, audio)

      assert_equal '/media/device/music/artist/song.wav', target_path.to_s
    end

    test 'does not add bpm to filename when audio has no bpm' do
      source_file = '/home/user/music/artist/song.wav'
      audio = stub(bpm: nil)
      target_path = resolver_for('Octatrack').resolve(source_file, audio)

      assert_equal '/media/device/music/artist/song.wav', target_path.to_s
    end

    test 'adds bpm to filename with file type conversion' do
      source_file = '/home/user/music/artist/song.m4a'
      audio = stub(bpm: 128)
      target_path = resolver_for('Octatrack').resolve(source_file, audio, target_file_type: 'wav')

      assert_equal '/media/device/music/artist/song 128 bpm.wav', target_path.to_s
    end

    test 'removes existing bpm from filename before adding new one' do
      source_file = '/home/user/music/artist/song 120 bpm.wav'
      audio = stub(bpm: 140)
      target_path = resolver_for('Octatrack').resolve(source_file, audio)

      assert_equal '/media/device/music/artist/song 140 bpm.wav', target_path.to_s
    end

    private

    def resolver_for(device_name)
      device = Device.find_by(name: device_name)
      PathResolver.new(@source_library, @target_library, device)
    end
  end
end
