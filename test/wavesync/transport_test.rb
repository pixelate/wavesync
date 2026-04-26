# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class TransportTest < Wavesync::TestCase
    test 'for returns Filesystem when transport is filesystem' do
      transport = Transport.for(name: 'OT', model: 'Octatrack', path: '/tmp/ot', transport: 'filesystem')
      assert_instance_of Transport::Filesystem, transport
      assert_equal '/tmp/ot', transport.working_directory
    end

    test 'for defaults to Filesystem when transport key is absent' do
      transport = Transport.for(name: 'OT', model: 'Octatrack', path: '/tmp/ot')
      assert_instance_of Transport::Filesystem, transport
    end

    test 'for returns Mtp when transport is mtp' do
      cache_root = Dir.mktmpdir
      transport = Transport::Mtp.new({ name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' }, cache_root: cache_root)
      assert_instance_of Transport::Mtp, transport
      assert_equal File.join(cache_root, 'tp-7'), transport.working_directory
    ensure
      FileUtils.rm_rf(cache_root) if cache_root
    end

    test 'for raises ArgumentError for unknown transport' do
      assert_raises(ArgumentError) do
        Transport.for(name: 'X', model: 'X', path: '/tmp/x', transport: 'bluetooth')
      end
    end
  end

  class FilesystemTransportTest < Wavesync::TestCase
    test 'commit! is a no-op' do
      transport = Transport::Filesystem.new(name: 'OT', model: 'Octatrack', path: '/tmp/ot', transport: 'filesystem')
      assert_nil transport.commit!
    end
  end

  class MtpTransportTest < Wavesync::TestCase
    def setup
      @cache_root = Dir.mktmpdir
      @libmtp = mock('Libmtp')
      @device_config = { name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' }
      @transport = Transport::Mtp.new(@device_config, libmtp: @libmtp, cache_root: @cache_root)
      @staging = @transport.working_directory
    end

    def teardown
      FileUtils.rm_rf(@cache_root)
    end

    test 'creates the staging directory under the cache root' do
      assert File.directory?(@staging)
      assert_equal File.join(@cache_root, 'tp-7'), @staging
    end

    test 'commit! creates missing folders, sends new files, and skips files that already match' do
      write_local_file('music/new.wav', 'aaaaaa')
      write_local_file('music/existing.wav', 'bbbb')

      @libmtp.expects(:files).returns([
                                        Libmtp::DeviceFile.new(id: 99, filename: 'existing.wav',
                                                               size: 4, parent_id: 50, storage_id: 0x00010001)
                                      ])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001),
                                          Libmtp::DeviceFolder.new(folder_id: 50, name: 'music',
                                                                   parent_id: 10, storage_id: 0x00010001)
                                        ])

      @libmtp.expects(:send_file).with(
        local_path: File.join(@staging, 'music/new.wav'),
        remote_filename: 'new.wav',
        parent_id: 50,
        storage_id: 0x00010001
      )
      @libmtp.expects(:send_file).with(has_entry(remote_filename: 'existing.wav')).never
      @libmtp.expects(:create_folder).never
      @libmtp.expects(:delete_file).never

      progress_calls = []
      @transport.commit! { |index, total, path| progress_calls << [index, total, path] }
      assert_equal [[0, 2, 'music/existing.wav'], [1, 2, 'music/new.wav']], progress_calls
    end

    test 'commit! creates intermediate folders for files written into a missing remote subdirectory' do
      write_local_file('music/sounds/kick.wav', 'aaaa')

      @libmtp.expects(:files).returns([])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001)
                                        ])
      @libmtp.expects(:create_folder).with(name: 'music', parent_id: 10, storage_id: 0x00010001).returns(20)
      @libmtp.expects(:create_folder).with(name: 'sounds', parent_id: 20, storage_id: 0x00010001).returns(30)
      @libmtp.expects(:send_file).with(
        local_path: File.join(@staging, 'music/sounds/kick.wav'),
        remote_filename: 'kick.wav',
        parent_id: 30,
        storage_id: 0x00010001
      )

      @transport.commit!
    end

    test 'commit! deletes a remote file with mismatched size before re-sending' do
      write_local_file('music/track.wav', 'aaaaaa')

      @libmtp.expects(:files).returns([
                                        Libmtp::DeviceFile.new(id: 99, filename: 'track.wav',
                                                               size: 999, parent_id: 50, storage_id: 0x00010001)
                                      ])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001),
                                          Libmtp::DeviceFolder.new(folder_id: 50, name: 'music',
                                                                   parent_id: 10, storage_id: 0x00010001)
                                        ])

      @libmtp.expects(:delete_file).with(id: 99)
      @libmtp.expects(:send_file).with(
        local_path: File.join(@staging, 'music/track.wav'),
        remote_filename: 'track.wav',
        parent_id: 50,
        storage_id: 0x00010001
      )

      @transport.commit!
    end

    test 'commit! raises DeviceNotFound when no storage id can be inferred' do
      write_local_file('music/track.wav', 'aaaa')

      @libmtp.expects(:files).returns([])
      @libmtp.expects(:folders).returns([])

      assert_raises(Libmtp::DeviceNotFound) { @transport.commit! }
    end

    test 'commit! does nothing when staging directory is empty' do
      @libmtp.expects(:files).returns([])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001)
                                        ])
      @libmtp.expects(:send_file).never
      @libmtp.expects(:create_folder).never

      @transport.commit!
    end

    test 'prepare! pulls device WAVs whose staging copy is missing or has a different size' do
      write_local_file('music/existing.wav', 'aaaa')
      write_local_file('music/up_to_date.wav', 'bbbbb')

      device_folders = [
        Libmtp::DeviceFolder.new(folder_id: 10, name: 'library', parent_id: 0, storage_id: 0x00010001),
        Libmtp::DeviceFolder.new(folder_id: 50, name: 'music', parent_id: 10, storage_id: 0x00010001)
      ]
      device_files = [
        Libmtp::DeviceFile.new(id: 100, filename: 'existing.wav', size: 6, parent_id: 50, storage_id: 0x00010001),
        Libmtp::DeviceFile.new(id: 101, filename: 'up_to_date.wav', size: 5, parent_id: 50, storage_id: 0x00010001),
        Libmtp::DeviceFile.new(id: 102, filename: 'new.wav', size: 8, parent_id: 50, storage_id: 0x00010001)
      ]
      @libmtp.expects(:files).returns(device_files)
      @libmtp.expects(:folders).returns(device_folders)

      @libmtp.expects(:get_file).with(id: 100, local_path: File.join(@staging, 'music/existing.wav'))
      @libmtp.expects(:get_file).with(id: 102, local_path: File.join(@staging, 'music/new.wav'))

      progress = []
      @transport.prepare! { |index, total, path| progress << [index, total, path] }
      assert_equal 2, progress.size
      assert_equal [0, 2], progress.first[0..1]
    end

    test 'prepare! ignores non-WAV device files' do
      write_local_file('music/track.mp3', 'a')

      @libmtp.expects(:files).returns([
                                        Libmtp::DeviceFile.new(id: 200, filename: 'track.mp3', size: 999,
                                                               parent_id: 50, storage_id: 0x00010001)
                                      ])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001),
                                          Libmtp::DeviceFolder.new(folder_id: 50, name: 'music',
                                                                   parent_id: 10, storage_id: 0x00010001)
                                        ])
      @libmtp.expects(:get_file).never

      @transport.prepare!
    end

    test 'prepare! ignores files outside the configured device path' do
      @libmtp.expects(:files).returns([
                                        Libmtp::DeviceFile.new(id: 300, filename: 'log.wav', size: 999,
                                                               parent_id: 60, storage_id: 0x00010001)
                                      ])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001),
                                          Libmtp::DeviceFolder.new(folder_id: 60, name: 'logs',
                                                                   parent_id: 0, storage_id: 0x00010001)
                                        ])
      @libmtp.expects(:get_file).never

      @transport.prepare!
    end

    test 'prepare! creates intermediate staging directories when pulling new files' do
      @libmtp.expects(:files).returns([
                                        Libmtp::DeviceFile.new(id: 400, filename: 'track.wav', size: 8,
                                                               parent_id: 70, storage_id: 0x00010001)
                                      ])
      @libmtp.expects(:folders).returns([
                                          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library',
                                                                   parent_id: 0, storage_id: 0x00010001),
                                          Libmtp::DeviceFolder.new(folder_id: 70, name: 'sounds',
                                                                   parent_id: 10, storage_id: 0x00010001)
                                        ])
      expected_local = File.join(@staging, 'sounds/track.wav')
      @libmtp.expects(:get_file).with(id: 400, local_path: expected_local)

      refute File.directory?(File.dirname(expected_local))
      @transport.prepare!
      assert File.directory?(File.dirname(expected_local))
    end

    private

    def write_local_file(relative_path, content)
      full_path = File.join(@staging, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.binwrite(full_path, content)
      full_path
    end
  end
end
