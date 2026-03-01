# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/path_resolver'
require_relative '../../lib/wavesync/device'
require_relative '../../lib/wavesync/audio'

module Wavesync
  class PathResolverCleanupTest < Wavesync::TestCase
    CONFIG_PATH = File.expand_path('../../config/devices.yml', __dir__)

    def setup
      Device.configure(path: CONFIG_PATH)
      @source_library = '/home/user/music'
      @target_library = '/media/device/music'
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

    test 'find_files_to_cleanup finds files with different bpm values' do
      FileUtils.mkdir_p('/tmp/test_cleanup_bpm/artist')
      FileUtils.touch('/tmp/test_cleanup_bpm/artist/song 120 bpm.wav')
      FileUtils.touch('/tmp/test_cleanup_bpm/artist/song 125 bpm.wav')

      device = Device.find_by(name: 'Octatrack')
      resolver = PathResolver.new(@source_library, '/tmp/test_cleanup_bpm', device)
      target_path = Pathname.new('/tmp/test_cleanup_bpm/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver.find_files_to_cleanup(target_path, audio)

      assert_equal 2, files.size
      assert_includes files.map(&:to_s), '/tmp/test_cleanup_bpm/artist/song 120 bpm.wav'
      assert_includes files.map(&:to_s), '/tmp/test_cleanup_bpm/artist/song 125 bpm.wav'

      FileUtils.rm_rf('/tmp/test_cleanup_bpm')
    end

    test 'find_files_to_cleanup finds both file without bpm and files with different bpm' do
      FileUtils.mkdir_p('/tmp/test_cleanup_mixed/artist')
      FileUtils.touch('/tmp/test_cleanup_mixed/artist/song.wav')
      FileUtils.touch('/tmp/test_cleanup_mixed/artist/song 120 bpm.wav')

      device = Device.find_by(name: 'Octatrack')
      resolver = PathResolver.new(@source_library, '/tmp/test_cleanup_mixed', device)
      target_path = Pathname.new('/tmp/test_cleanup_mixed/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver.find_files_to_cleanup(target_path, audio)

      assert_equal 2, files.size
      assert_includes files.map(&:to_s), '/tmp/test_cleanup_mixed/artist/song.wav'
      assert_includes files.map(&:to_s), '/tmp/test_cleanup_mixed/artist/song 120 bpm.wav'

      FileUtils.rm_rf('/tmp/test_cleanup_mixed')
    end

    test 'find_files_to_cleanup does not include the target file itself' do
      FileUtils.mkdir_p('/tmp/test_cleanup_self/artist')
      FileUtils.touch('/tmp/test_cleanup_self/artist/song 140 bpm.wav')
      FileUtils.touch('/tmp/test_cleanup_self/artist/song 120 bpm.wav')

      device = Device.find_by(name: 'Octatrack')
      resolver = PathResolver.new(@source_library, '/tmp/test_cleanup_self', device)
      target_path = Pathname.new('/tmp/test_cleanup_self/artist/song 140 bpm.wav')
      audio = stub(bpm: 140)
      files = resolver.find_files_to_cleanup(target_path, audio)

      assert_equal 1, files.size
      assert_equal '/tmp/test_cleanup_self/artist/song 120 bpm.wav', files.first.to_s
      refute_includes files.map(&:to_s), '/tmp/test_cleanup_self/artist/song 140 bpm.wav'

      FileUtils.rm_rf('/tmp/test_cleanup_self')
    end

    private

    def resolver_for(device_name)
      device = Device.find_by(name: device_name)
      PathResolver.new(@source_library, @target_library, device)
    end
  end
end
