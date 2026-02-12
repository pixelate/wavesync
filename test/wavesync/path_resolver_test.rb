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

    test 'find_files_to_cleanup returns empty array when no bpm_source' do
      target_path = Pathname.new('/media/device/music/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver_for('TP-7').find_files_to_cleanup(target_path, audio)

      assert_equal [], files
    end

    test 'find_files_to_cleanup returns empty array when audio has no bpm' do
      target_path = Pathname.new('/media/device/music/artist/song.wav')
      audio = stub(bpm: nil)
      files = resolver_for('Octatrack').find_files_to_cleanup(target_path, audio)

      assert_equal [], files
    end

    test 'find_files_to_cleanup finds file without bpm when it exists' do
      FileUtils.mkdir_p('/tmp/test_cleanup/artist')
      FileUtils.touch('/tmp/test_cleanup/artist/song.wav')

      device = Device.find_by(name: 'Octatrack')
      resolver = PathResolver.new(@source_library, '/tmp/test_cleanup', device)
      target_path = Pathname.new('/tmp/test_cleanup/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver.find_files_to_cleanup(target_path, audio)

      assert_equal 1, files.size
      assert_equal '/tmp/test_cleanup/artist/song.wav', files.first.to_s

      FileUtils.rm_rf('/tmp/test_cleanup')
    end

    test 'find_files_to_cleanup returns empty when file without bpm does not exist' do
      target_path = Pathname.new('/media/device/music/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver_for('Octatrack').find_files_to_cleanup(target_path, audio)

      assert_equal [], files
    end

    private

    def resolver_for(device_name)
      device = Device.find_by(name: device_name)
      PathResolver.new(@source_library, @target_library, device)
    end
  end
end
