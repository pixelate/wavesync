# frozen_string_literal: true

require 'tempfile'
require 'tmpdir'
require 'fileutils'
require_relative 'test_case'
require_relative '../../lib/wavesync/logger'
require_relative '../../lib/wavesync/audio_format'
require_relative '../../lib/wavesync/ffmpeg'
require_relative '../../lib/wavesync/audio'
require_relative '../../lib/wavesync/acid_chunk'

module Wavesync
  class AudioTest < Wavesync::TestCase
    test 'sample_rate returns 44100 for 44100hz fixture' do
      assert_equal 44_100, audio('44100_16.wav').sample_rate
    end

    test 'sample_rate returns 48000 for 48000hz fixture' do
      assert_equal 48_000, audio('48000_16.wav').sample_rate
    end

    test 'sample_rate returns 88200 for 88200hz fixture' do
      assert_equal 88_200, audio('88200_16.wav').sample_rate
    end

    test 'sample_rate returns 96000 for 96000hz fixture' do
      assert_equal 96_000, audio('96000_24.wav').sample_rate
    end

    test 'sample_rate returns 22050 for 22050hz fixture' do
      assert_equal 22_050, audio('22050_16.wav').sample_rate
    end

    test 'bit_depth returns 8 for 8-bit wav' do
      assert_equal 8, audio('44100_8.wav').bit_depth
    end

    test 'bit_depth returns 16 for 16-bit wav' do
      assert_equal 16, audio('44100_16.wav').bit_depth
    end

    test 'bit_depth returns 24 for 24-bit wav' do
      assert_equal 24, audio('44100_24.wav').bit_depth
    end

    test 'bpm returns nil for clean wav' do
      assert_nil audio('44100_16.wav').bpm
    end

    test 'bpm returns nil for clean mp3' do
      assert_nil audio('44100.mp3').bpm
    end

    test 'bpm returns nil for clean m4a' do
      assert_nil audio('44100.m4a').bpm
    end

    test 'bpm returns nil for clean aif' do
      assert_nil audio('44100_16.aif').bpm
    end

    test 'bpm returns nil for clean aiff' do
      assert_nil audio('44100_16.aiff').bpm
    end

    test 'transliterate_tags replaces umlauts across all supported id3v2 frames for mp3' do
      with_temp_copy('44100.mp3') do |path|
        write_id3v2_frames(
          path,
          'TIT2' => 'Jóga',
          'TPE1' => 'Björk',
          'TALB' => 'Åström Remixes',
          'TPE2' => 'Sigur Rós',
          'TCON' => 'Électronique',
          'TCOM' => 'Jean-Michel Jarré',
          'TENC' => 'Encöder',
          'TCMP' => '1'
        )

        Audio.new(path).transliterate_tags

        frames = read_id3v2_frames(path)
        assert_equal 'Joga', frames['TIT2']
        assert_equal 'Bjork', frames['TPE1']
        assert_equal 'Astrom Remixes', frames['TALB']
        assert_equal 'Sigur Ros', frames['TPE2']
        assert_equal 'Electronique', frames['TCON']
        assert_equal 'Jean-Michel Jarre', frames['TCOM']
        assert_equal 'Encoder', frames['TENC']
        assert_equal '1', frames['TCMP']
      end
    end

    test 'transliterate_tags leaves ascii-only tags unchanged' do
      with_temp_copy('44100.mp3') do |path|
        write_id3v2_frames(path, 'TPE1' => 'Aphex Twin', 'TIT2' => 'Windowlicker')

        Audio.new(path).transliterate_tags

        frames = read_id3v2_frames(path)
        assert_equal 'Aphex Twin', frames['TPE1']
        assert_equal 'Windowlicker', frames['TIT2']
      end
    end

    test 'transliterate_tags is a no-op for non-mp3 files' do
      with_temp_copy('44100_16.wav') do |path|
        Audio.new(path).transliterate_tags
      end
    end

    test 'transliterated_tag_changes returns changed tag values for tags with diacritics' do
      with_temp_copy('44100.mp3') do |path|
        write_id3v2_frames(path, 'TIT2' => 'Jóga', 'TPE1' => 'Aphex Twin')
        changes = Audio.new(path).transliterated_tag_changes
        assert_equal 'Joga', changes['title']
        assert_equal false, changes.key?('artist')
      end
    end

    test 'transliterated_tag_changes returns empty hash when no diacritics present' do
      with_temp_copy('44100.mp3') do |path|
        write_id3v2_frames(path, 'TIT2' => 'Windowlicker', 'TPE1' => 'Aphex Twin')
        assert_equal({}, Audio.new(path).transliterated_tag_changes)
      end
    end

    test 'write_bpm round-trips for wav via acid chunk' do
      with_temp_copy('44100_16.wav') do |path|
        Audio.new(path).write_bpm(128)
        assert_equal 128, Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for mp3 via id3v2' do
      with_temp_copy('44100.mp3') do |path|
        Audio.new(path).write_bpm(140)
        assert_equal '140', Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for m4a via tmpo tag' do
      with_temp_copy('44100.m4a') do |path|
        Audio.new(path).write_bpm(120)
        assert_equal 120, Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for aif via id3v2' do
      with_temp_copy('44100_16.aif') do |path|
        Audio.new(path).write_bpm(130)
        assert_equal '130', Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for aiff via id3v2' do
      with_temp_copy('44100_16.aiff') do |path|
        Audio.new(path).write_bpm(130)
        assert_equal '130', Audio.new(path).bpm
      end
    end

    test '#format returns an AudioFormat with file type, sample rate, and bit depth' do
      format = audio('44100_16.wav').format
      assert_instance_of AudioFormat, format
      assert_equal 'wav', format.file_type
      assert_equal 44_100, format.sample_rate
      assert_equal 16, format.bit_depth
    end

    test 'find_all returns files for all supported extensions' do
      files = Audio.find_all(FIXTURES_PATH)
      exts = files.map { |f| File.extname(f).downcase }.uniq.sort
      assert_equal %w[.aif .aiff .m4a .mp3 .wav], exts
    end

    test 'find_all does not return unsupported file types' do
      files = Audio.find_all(FIXTURES_PATH)
      files.each do |f|
        assert_includes Audio::SUPPORTED_FORMATS, File.extname(f).downcase
      end
    end

    test 'transcode from 24-bit wav to mp3 produces a valid mp3' do
      audio_obj = audio('96000_24.wav')
      Dir.mktmpdir do |dir|
        output_path = File.join(dir, 'output.mp3')
        result = audio_obj.transcode(output_path, target_sample_rate: 44_100, target_file_type: 'mp3', target_bit_depth: 24)
        assert_equal true, result
        assert File.exist?(output_path)
        assert_equal 44_100, Audio.new(output_path).sample_rate
      end
    end

    test 'transcode returns false and logs error with all arguments when ENOENT is raised' do
      audio_obj = audio('44100_16.wav')
      Wavesync::FFMPEG.any_instance.stubs(:run).raises(Errno::ENOENT)
      Logger.expects(:log_error).with(
        instance_of(Errno::ENOENT),
        call_site: 'Audio#transcode',
        arguments: {
          target_path: '/tmp/output.wav',
          target_sample_rate: 48_000,
          target_file_type: 'wav',
          target_bit_depth: 24,
          padding_seconds: nil
        }
      )
      result = audio_obj.transcode('/tmp/output.wav', target_sample_rate: 48_000, target_file_type: 'wav', target_bit_depth: 24)
      assert_equal false, result
    end

    private

    def audio(name)
      Audio.new(File.join(FIXTURES_PATH, name))
    end

    def write_id3v2_frames(path, frames)
      ext = File.extname(path)
      tmp = Tempfile.new(['audio_test_write', ext])
      tmp.close
      cmd = FFMPEG.new.input(path).copy_streams.map_metadata(0)
      frames.each do |frame_id, value|
        cmd.metadata(Audio::FRAME_ID_TO_FFMPEG_KEY.fetch(frame_id, frame_id), value)
      end
      cmd.run(tmp.path)
      FileUtils.cp(tmp.path, path)
    ensure
      tmp&.unlink
    end

    def read_id3v2_frames(path)
      FFMPEG::Probe.new(path).tags.each_with_object({}) do |(key, value), result|
        frame_id = Audio::FFMPEG_KEY_TO_FRAME_ID.fetch(key, key)
        result[frame_id] = value
      end
    end

    def with_temp_copy(name)
      ext = File.extname(name)
      tmp = Tempfile.new(['audio_test', ext])
      FileUtils.cp(File.join(FIXTURES_PATH, name), tmp.path)
      yield tmp.path
    ensure
      tmp&.close
      tmp&.unlink
    end
  end
end
