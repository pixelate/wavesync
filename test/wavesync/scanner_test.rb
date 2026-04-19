# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class ScannerTest < Wavesync::TestCase
    def setup
      silence_output
      Logger.stubs(:log_error)
      Logger.stubs(:configure)
      @source_dir = Dir.mktmpdir
      @target_dir = Dir.mktmpdir
      @device = Device.find_by(name: 'TP-7')
    end

    def teardown
      restore_output
      FileUtils.rm_rf(@source_dir)
      FileUtils.rm_rf(@target_dir)
    end

    test 'initializing configures error logger with source library path' do
      Logger.expects(:configure).with(File.expand_path(@source_dir))
      Scanner.new(@source_dir)
    end

    test 'sync calls system sync to flush filesystem buffers after completing' do
      Scanner.any_instance.expects(:system).with('sync')
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync writes cue points from target wav to source wav when source has none' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      target_wav = File.join(@target_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), target_wav)
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Marker' }]
      CueChunk.write(target_wav, "#{target_wav}.tmp", cue_points)
      FileUtils.mv("#{target_wav}.tmp", target_wav)

      Scanner.new(@source_dir).sync(@target_dir, @device)

      result = CueChunk.read(source_wav)
      assert_equal 1, result.size
      assert_equal 44_100, result[0][:sample_offset]
      assert_equal 'Marker', result[0][:label]
    end

    test 'sync does not write cue points to source wav when source already has the same cue points' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil }]
      CueChunk.write(source_wav, "#{source_wav}.tmp", cue_points)
      FileUtils.mv("#{source_wav}.tmp", source_wav)

      target_wav = File.join(@target_dir, 'track.wav')
      FileUtils.cp(source_wav, target_wav)

      Audio.any_instance.expects(:write_cue_points).never
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync does not write cue points to source when source is not a wav' do
      source_mp3 = File.join(@source_dir, 'track.mp3')
      FileUtils.cp(fixture('44100.mp3'), source_mp3)

      target_mp3 = File.join(@target_dir, 'track.mp3')
      FileUtils.cp(fixture('44100.mp3'), target_mp3)

      Audio.any_instance.expects(:write_cue_points).never
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'safe_copy logs error with source and target when ENOENT is raised' do
      source_wav = File.join(File.expand_path(@source_dir), 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      expected_target = Pathname(File.join(File.expand_path(@target_dir), 'track.wav'))
      FileUtils.stubs(:install).raises(Errno::ENOENT)
      Logger.expects(:log_error).with(
        instance_of(Errno::ENOENT),
        call_site: 'Scanner#safe_copy',
        arguments: { source: source_wav, target: expected_target }
      )
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync waits for sync throttle after copying a file to TP-7' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.any_instance.expects(:wait_for_sync).once
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync creates throttle with file_size mode by default for TP-7' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.expects(:new).with(mode: :file_size).returns(stub(wait_for_sync: nil))
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync creates throttle with disk_space mode when sync_throttle option is :disk_space' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.expects(:new).with(mode: :disk_space).returns(stub(wait_for_sync: nil))
      Scanner.new(@source_dir).sync(@target_dir, @device, sync_throttle: :disk_space)
    end

    test 'sync creates throttle with fixed_delay mode when sync_throttle option is :fixed_delay' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.expects(:new).with(mode: :fixed_delay).returns(stub(wait_for_sync: nil))
      Scanner.new(@source_dir).sync(@target_dir, @device, sync_throttle: :fixed_delay)
    end

    test 'sync creates throttle with lsof mode when sync_throttle option is :lsof' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.expects(:new).with(mode: :lsof).returns(stub(wait_for_sync: nil))
      Scanner.new(@source_dir).sync(@target_dir, @device, sync_throttle: :lsof)
    end

    test 'sync does not use throttle for Octatrack' do
      octatrack_device = Device.find_by(name: 'Octatrack')
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.any_instance.expects(:wait_for_sync).never
      Scanner.new(@source_dir).sync(@target_dir, octatrack_device)
    end

    test 'sync enables throttle for Octatrack when sync_throttle option is passed' do
      octatrack_device = Device.find_by(name: 'Octatrack')
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.any_instance.expects(:wait_for_sync).once
      Scanner.new(@source_dir).sync(@target_dir, octatrack_device, sync_throttle: :fixed_delay)
    end

    test 'sync does not wait for throttle when file is skipped' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)
      target_wav = File.join(@target_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), target_wav)

      stub_ffmpeg_movie(sample_rate: 44_100, bit_depth: 16, duration: 1.0)

      FileSyncThrottle.any_instance.expects(:wait_for_sync).never
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end

    def stub_ffmpeg_movie(sample_rate:, bit_depth:, duration:)
      audio_stream = { codec_type: 'audio', bits_per_sample: bit_depth }
      ffmpeg_movie = stub(
        audio_sample_rate: sample_rate,
        duration: duration,
        audio_bitrate: bit_depth * sample_rate,
        audio_codec: 'pcm_s16le',
        valid?: true,
        metadata: { streams: [audio_stream] }
      )
      FFMPEG::Movie.stubs(:new).returns(ffmpeg_movie)
    end
  end
end
