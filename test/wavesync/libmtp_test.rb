# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class LibmtpTest < Wavesync::TestCase
    MTP_FILES_OUTPUT = <<~OUT
      libmtp version: 1.1.21

      Listing File Information on Device with name: TP-7
      File ID: 4
         Filename: track1.wav
         File size 12345 (0x3039 bytes)
         Parent ID: 3
         Storage ID: 0x00010001
         Filetype: WAV audio file
      File ID: 5
         Filename: track2.mp3
         File size 6789 (0x1A85 bytes)
         Parent ID: 3
         Storage ID: 0x00010001
         Filetype: MP3 audio file
      OK.
    OUT

    MTP_FOLDERS_OUTPUT = <<~OUT
      Folder Listing for Device 0 (TP-7):
      Storage: 0x00010001
      1 library
        3 music
          7 stems
        4 sounds
      2 logs
    OUT

    def setup
      Libmtp.reset_tool_path_cache!
      @libmtp = Libmtp.new
    end

    test 'files parses mtp-files output into DeviceFile entries' do
      stub_tool_path('mtp-files', '/usr/local/bin/mtp-files')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-files').returns([MTP_FILES_OUTPUT, '', success_status])

      result = @libmtp.files

      assert_equal 2, result.size
      assert_equal 4, result[0].id
      assert_equal 'track1.wav', result[0].filename
      assert_equal 12_345, result[0].size
      assert_equal 3, result[0].parent_id
      assert_equal 0x00010001, result[0].storage_id

      assert_equal 5, result[1].id
      assert_equal 'track2.mp3', result[1].filename
      assert_equal 6789, result[1].size
    end

    test 'folders parses mtp-folders output into DeviceFolder entries with parent ids derived from indentation' do
      stub_tool_path('mtp-folders', '/usr/local/bin/mtp-folders')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-folders').returns([MTP_FOLDERS_OUTPUT, '', success_status])

      result = @libmtp.folders
      by_id = result.to_h { |folder| [folder.folder_id, folder] }

      assert_equal 5, result.size
      assert_equal 0, by_id[1].parent_id
      assert_equal 'library', by_id[1].name
      assert_equal 0x00010001, by_id[1].storage_id
      assert_equal 1, by_id[3].parent_id
      assert_equal 3, by_id[7].parent_id
      assert_equal 1, by_id[4].parent_id
      assert_equal 0, by_id[2].parent_id
    end

    test 'send_file invokes mtp-sendfile with parent and storage ids' do
      stub_tool_path('mtp-sendfile', '/usr/local/bin/mtp-sendfile')
      Open3.expects(:capture3).with(
        '/usr/local/bin/mtp-sendfile', '-p', '7', '-s', '0x00010001', '/local/track.wav', 'track.wav'
      ).returns(['', '', success_status])

      @libmtp.send_file(local_path: '/local/track.wav', remote_filename: 'track.wav', parent_id: 7, storage_id: 0x00010001)
    end

    test 'create_folder parses the new folder id from mtp-newfolder output' do
      stub_tool_path('mtp-newfolder', '/usr/local/bin/mtp-newfolder')
      Open3.expects(:capture3).with(
        '/usr/local/bin/mtp-newfolder', 'subfolder', '3', '0x00010001'
      ).returns(["New folder created with ID: 42\n", '', success_status])

      assert_equal 42, @libmtp.create_folder(name: 'subfolder', parent_id: 3, storage_id: 0x00010001)
    end

    test 'create_folder raises when output cannot be parsed' do
      stub_tool_path('mtp-newfolder', '/usr/local/bin/mtp-newfolder')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-newfolder', 'subfolder', '3', '0x00000001')
           .returns(['Folder creation failed.', '', success_status])

      assert_raises(Libmtp::Error) do
        @libmtp.create_folder(name: 'subfolder', parent_id: 3, storage_id: 1)
      end
    end

    test 'delete_file invokes mtp-delfile with -n and the object id' do
      stub_tool_path('mtp-delfile', '/usr/local/bin/mtp-delfile')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-delfile', '-n', '12').returns(['', '', success_status])

      @libmtp.delete_file(id: 12)
    end

    test 'get_file invokes mtp-getfile with the id and local path' do
      stub_tool_path('mtp-getfile', '/usr/local/bin/mtp-getfile')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-getfile', '17', '/tmp/local.wav').returns(['', '', success_status])

      @libmtp.get_file(id: 17, local_path: '/tmp/local.wav')
    end

    test 'failed tool invocations raise Libmtp::Error with stderr message' do
      stub_tool_path('mtp-files', '/usr/local/bin/mtp-files')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-files')
           .returns(['', "couldn't open device", failure_status])

      error = assert_raises(Libmtp::Error) { @libmtp.files }
      assert_match "couldn't open device", error.message
    end

    test 'tool_path raises ToolNotInstalled when which fails' do
      Open3.expects(:capture3).with('which', 'mtp-files').returns(['', '', failure_status])

      assert_raises(Libmtp::ToolNotInstalled) { Libmtp.tool_path('mtp-files') }
    end

    test 'detected? returns false when libmtp is not installed' do
      Open3.expects(:capture3).with('which', 'mtp-detect').returns(['', '', failure_status])

      refute @libmtp.detected?
    end

    test 'detected? returns true when mtp-detect succeeds' do
      stub_tool_path('mtp-detect', '/usr/local/bin/mtp-detect')
      Open3.expects(:capture3).with('/usr/local/bin/mtp-detect').returns(['ok', '', success_status])

      assert @libmtp.detected?
    end

    private

    def stub_tool_path(tool, path)
      Open3.expects(:capture3).with('which', tool).returns(["#{path}\n", '', success_status]).at_most_once
    end

    def success_status
      stub('Process::Status', success?: true)
    end

    def failure_status
      stub('Process::Status', success?: false)
    end
  end
end
