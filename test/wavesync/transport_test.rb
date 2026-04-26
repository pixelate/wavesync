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

    test 'prepare! replaces the staging copy when the device cue points differ from the local cue points' do
      staging_path = File.join(@staging, 'music/track.wav')
      write_wav_with_cues(staging_path, [{ identifier: 1, sample_offset: 100, label: 'A' }])

      device_cues = [{ identifier: 1, sample_offset: 200, label: 'B' }]
      fake = build_fake_libmtp(
        files: [Libmtp::DeviceFile.new(id: 100, filename: 'track.wav', size: 0, parent_id: 50, storage_id: 0x00010001)],
        folders: music_folders,
        pull_payload: { 100 => build_wav_payload_with_cues(device_cues) }
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      transport.prepare!

      result = CueChunk.read(staging_path)
      assert_equal 1, result.size
      assert_equal 200, result.first[:sample_offset]
      assert_equal 'B', result.first[:label]
    end

    test 'prepare! leaves the staging copy unchanged when cue points match' do
      cues = [{ identifier: 1, sample_offset: 100, label: 'A' }]
      staging_path = File.join(@staging, 'music/track.wav')
      write_wav_with_cues(staging_path, cues)
      original_bytes = File.binread(staging_path)

      fake = build_fake_libmtp(
        files: [Libmtp::DeviceFile.new(id: 100, filename: 'track.wav', size: 0, parent_id: 50, storage_id: 0x00010001)],
        folders: music_folders,
        pull_payload: { 100 => build_wav_payload_with_cues(cues) }
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      transport.prepare!

      assert_equal original_bytes, File.binread(staging_path)
    end

    test 'prepare! materializes a new staging file when a device WAV has cue points and no local copy exists' do
      device_cues = [{ identifier: 1, sample_offset: 50, label: 'X' }]
      fake = build_fake_libmtp(
        files: [Libmtp::DeviceFile.new(id: 100, filename: 'new.wav', size: 0, parent_id: 50, storage_id: 0x00010001)],
        folders: music_folders,
        pull_payload: { 100 => build_wav_payload_with_cues(device_cues) }
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      transport.prepare!

      staged_path = File.join(@staging, 'music/new.wav')
      assert File.exist?(staged_path)
      assert_equal 50, CueChunk.read(staged_path).first[:sample_offset]
    end

    test 'prepare! ignores non-WAV device files' do
      fake = build_fake_libmtp(
        files: [Libmtp::DeviceFile.new(id: 200, filename: 'track.mp3', size: 999, parent_id: 50, storage_id: 0x00010001)],
        folders: music_folders
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      transport.prepare!

      assert_equal [], fake.get_file_calls
    end

    test 'prepare! ignores files outside the configured device path' do
      fake = build_fake_libmtp(
        files: [Libmtp::DeviceFile.new(id: 300, filename: 'log.wav', size: 999, parent_id: 60, storage_id: 0x00010001)],
        folders: [
          Libmtp::DeviceFolder.new(folder_id: 10, name: 'library', parent_id: 0, storage_id: 0x00010001),
          Libmtp::DeviceFolder.new(folder_id: 60, name: 'logs', parent_id: 0, storage_id: 0x00010001)
        ]
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      transport.prepare!

      assert_equal [], fake.get_file_calls
    end

    test 'prepare! reports progress for each candidate WAV' do
      cues = [{ identifier: 1, sample_offset: 100, label: 'A' }]
      payload = build_wav_payload_with_cues(cues)
      fake = build_fake_libmtp(
        files: [
          Libmtp::DeviceFile.new(id: 100, filename: 'a.wav', size: 0, parent_id: 50, storage_id: 0x00010001),
          Libmtp::DeviceFile.new(id: 101, filename: 'b.wav', size: 0, parent_id: 50, storage_id: 0x00010001)
        ],
        folders: music_folders,
        pull_payload: { 100 => payload, 101 => payload }
      )
      transport = Transport::Mtp.new(@device_config, libmtp: fake, cache_root: @cache_root)

      progress = []
      transport.prepare! { |index, total, path| progress << [index, total, path] }
      assert_equal [[0, 2, 'music/a.wav'], [1, 2, 'music/b.wav']], progress
    end

    private

    def write_local_file(relative_path, content)
      full_path = File.join(@staging, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.binwrite(full_path, content)
      full_path
    end

    def write_wav_with_cues(path, cues)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.cp(File.join(FIXTURES_PATH, '44100_16.wav'), path)
      tmp = "#{path}.tmp"
      CueChunk.write(path, tmp, cues)
      FileUtils.mv(tmp, path)
    end

    def build_wav_payload_with_cues(cues)
      Tempfile.create(['wav_payload', '.wav']) do |file|
        file.close
        write_wav_with_cues(file.path, cues)
        File.binread(file.path)
      end
    end

    def build_fake_libmtp(files:, folders:, pull_payload: {})
      FakeLibmtp.new(files: files, folders: folders, pull_payload: pull_payload)
    end

    def music_folders
      [
        Libmtp::DeviceFolder.new(folder_id: 10, name: 'library', parent_id: 0, storage_id: 0x00010001),
        Libmtp::DeviceFolder.new(folder_id: 50, name: 'music', parent_id: 10, storage_id: 0x00010001)
      ]
    end

    class FakeLibmtp
      attr_reader :files, :folders, :get_file_calls

      def initialize(files:, folders:, pull_payload: {})
        @files = files
        @folders = folders
        @pull_payload = pull_payload
        @get_file_calls = []
      end

      def get_file(id:, local_path:)
        @get_file_calls << { id: id, local_path: local_path }
        File.binwrite(local_path, @pull_payload.fetch(id, ''))
      end
    end
  end
end
