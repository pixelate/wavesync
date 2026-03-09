# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_case'
require_relative '../../lib/wavesync/set'
require_relative '../../lib/wavesync/device'
require_relative '../../lib/wavesync/octatrack_exporter'

module Wavesync
  class OctatrackExporterTest < Wavesync::TestCase
    def setup
      @tmp = Dir.mktmpdir
      @library = File.join(@tmp, 'library')
      @device_audio_path = File.join(@tmp, 'device', 'AUDIO')
      @projects_path = File.join(@tmp, 'device', 'LIBRARY')
      FileUtils.mkdir_p(@library)
      FileUtils.mkdir_p(@device_audio_path)
      FileUtils.mkdir_p(@projects_path)
      @track1 = File.join(@library, 'Artist A', 'track1.wav')
      @track2 = File.join(@library, 'Artist B', 'track2.wav')
    end

    def teardown
      FileUtils.rm_rf(@tmp)
    end

    def exporter(tracks = [@track1])
      set = Set.new(@library, 'my_set', tracks)
      OctatrackExporter.new(set, @library, @device_audio_path, @projects_path)
    end

    def project_dir
      File.join(@projects_path, 'MY_SET')
    end

    test 'export creates a project directory named after the set in uppercase' do
      exporter.export
      assert Dir.exist?(project_dir)
    end

    test 'export returns the project directory path' do
      result = exporter.export
      assert_equal project_dir, result
    end

    test 'export creates project.work' do
      exporter.export
      assert File.exist?(File.join(project_dir, 'project.work'))
    end

    test 'export creates bank01.work through bank16.work' do
      exporter.export
      1.upto(16) { |n| assert File.exist?(File.join(project_dir, "bank#{n.to_s.rjust(2, '0')}.work")) }
    end

    test 'export creates arr01.work through arr08.work' do
      exporter.export
      1.upto(8) { |n| assert File.exist?(File.join(project_dir, "arr#{n.to_s.rjust(2, '0')}.work")) }
    end

    test 'export creates markers.work' do
      exporter.export
      assert File.exist?(File.join(project_dir, 'markers.work'))
    end

    test 'project.work contains the Octatrack project type header' do
      exporter.export
      assert_includes project_work, 'TYPE=OCTATRACK DPS-1 PROJECT'
    end

    test 'project.work uses CRLF line endings' do
      exporter.export
      assert_includes File.binread(File.join(project_dir, 'project.work')), "\r\n"
    end

    test 'project.work includes FLEX slots 129 through 136' do
      exporter.export
      assert_includes project_work, "TYPE=FLEX\r\nSLOT=129"
      assert_includes project_work, "TYPE=FLEX\r\nSLOT=136"
    end

    test 'project.work assigns tracks to sequential STATIC slots starting at 1' do
      exporter([@track1, @track2]).export
      assert_includes project_work, "TYPE=STATIC\r\nSLOT=001"
      assert_includes project_work, "TYPE=STATIC\r\nSLOT=002"
    end

    test 'project.work slot numbers are zero-padded to 3 digits' do
      exporter.export
      assert_includes project_work, 'SLOT=001'
    end

    test 'project.work PATH is relative from project dir to the audio folder' do
      exporter.export
      assert_includes project_work, 'PATH=../AUDIO/Artist A/track1.wav'
    end

    test 'project.work PATH uses the device audio folder name' do
      custom_audio = File.join(@tmp, 'device', 'SAMPLES')
      FileUtils.mkdir_p(custom_audio)
      set = Set.new(@library, 'my_set', [@track1])
      OctatrackExporter.new(set, @library, custom_audio, @projects_path).export
      content = File.read(File.join(project_dir, 'project.work'))
      assert_includes content, 'PATH=../SAMPLES/Artist A/track1.wav'
    end

    test 'project.work preserves subdirectory structure in PATH' do
      track = File.join(@library, 'Artist B', 'Album C', 'track.wav')
      exporter([track]).export
      assert_includes project_work, 'PATH=../AUDIO/Artist B/Album C/track.wav'
    end

    test 'bank02 through bank16 are identical to the blank template' do
      exporter.export
      bank02 = File.binread(File.join(project_dir, 'bank02.work'))
      3.upto(16) do |n|
        assert_equal bank02, File.binread(File.join(project_dir, "bank#{n.to_s.rjust(2, '0')}.work"))
      end
    end

    test 'arr files are all identical' do
      exporter.export
      arr01 = File.binread(File.join(project_dir, 'arr01.work'))
      2.upto(8) do |n|
        assert_equal arr01, File.binread(File.join(project_dir, "arr#{n.to_s.rjust(2, '0')}.work"))
      end
    end

    test 'bank01 track 1 is assigned to static slot 1' do
      exporter.export
      bank01 = File.binread(File.join(project_dir, 'bank01.work'))
      OctatrackExporter::TRACK_ASSIGNMENT_OFFSETS.each do |offset|
        assert_equal 0x80, bank01.getbyte(offset),     "track 1 tag at 0x#{offset.to_s(16)}"
        assert_equal 1,    bank01.getbyte(offset + 1), "track 1 slot at 0x#{offset.to_s(16)}"
      end
    end

    test 'bank01 track 5 is assigned to static slot 2' do
      exporter.export
      bank01 = File.binread(File.join(project_dir, 'bank01.work'))
      OctatrackExporter::TRACK_ASSIGNMENT_OFFSETS.each do |offset|
        track5_offset = offset + (4 * 5)
        assert_equal 0x84, bank01.getbyte(track5_offset),     "track 5 tag at 0x#{track5_offset.to_s(16)}"
        assert_equal 2,    bank01.getbyte(track5_offset + 1), "track 5 slot at 0x#{track5_offset.to_s(16)}"
      end
    end

    test 'project.work converts mp3 path to wav extension when device is provided' do
      track = File.join(@library, 'Artist A', 'track.mp3')
      octatrack = Device.find_by(name: 'Octatrack')
      set = Set.new(@library, 'my_set', [track])
      OctatrackExporter.new(set, @library, @device_audio_path, @projects_path, device: octatrack).export
      assert_includes project_work, 'PATH=../AUDIO/Artist A/track.wav'
    end

    test 'project.work appends bpm to path when track has bpm' do
      octatrack = Device.find_by(name: 'Octatrack')
      set = Set.new(@library, 'my_set', [@track1])
      OctatrackExporter.any_instance.stubs(:read_bpm).returns(120)
      OctatrackExporter.new(set, @library, @device_audio_path, @projects_path, device: octatrack).export
      assert_includes project_work, 'PATH=../AUDIO/Artist A/track1 120 bpm.wav'
    end

    test 'project.work does not append bpm when track has no bpm' do
      octatrack = Device.find_by(name: 'Octatrack')
      set = Set.new(@library, 'my_set', [@track1])
      OctatrackExporter.any_instance.stubs(:read_bpm).returns(nil)
      OctatrackExporter.new(set, @library, @device_audio_path, @projects_path, device: octatrack).export
      assert_includes project_work, 'PATH=../AUDIO/Artist A/track1.wav'
    end

    test 'bank01 checksum is valid' do
      exporter.export
      bank01 = File.binread(File.join(project_dir, 'bank01.work')).bytes
      expected = (bank01[0..-2].sum - 1) % 256
      assert_equal expected, bank01.last
    end

    private

    def project_work
      File.read(File.join(project_dir, 'project.work'))
    end
  end
end
