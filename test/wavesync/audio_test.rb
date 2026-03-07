# frozen_string_literal: true

require 'tempfile'
require 'fileutils'
require_relative 'test_case'
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
      assert_nil audio('44100_16.mp3').bpm
    end

    test 'bpm returns nil for clean m4a' do
      assert_nil audio('44100_16.m4a').bpm
    end

    test 'bpm returns nil for clean aif' do
      assert_nil audio('44100_16.aif').bpm
    end

    test 'bpm returns nil for clean aiff' do
      assert_nil audio('44100_16.aiff').bpm
    end

    test 'write_bpm round-trips for wav via acid chunk' do
      with_temp_copy('44100_16.wav') do |path|
        Audio.new(path).write_bpm(128)
        assert_equal 128, Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for mp3 via id3v2' do
      with_temp_copy('44100_16.mp3') do |path|
        Audio.new(path).write_bpm(140)
        assert_equal '140', Audio.new(path).bpm
      end
    end

    test 'write_bpm round-trips for m4a via tmpo tag' do
      with_temp_copy('44100_16.m4a') do |path|
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

    private

    def audio(name)
      Audio.new(File.join(FIXTURES_PATH, name))
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
