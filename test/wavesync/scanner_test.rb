# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class ScannerTest < Wavesync::TestCase
    def setup
      silence_output
      Logger.stubs(:log_error)
      Logger.stubs(:configure)
      Logger.stubs(:log_run_time)
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

    test 'sync logs run time after completing' do
      Logger.expects(:log_run_time).once
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

      Scanner.new(@source_dir).sync(@target_dir, @device, pull_cue_points: true)

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
      Scanner.new(@source_dir).sync(@target_dir, @device, pull_cue_points: true)
    end

    test 'sync does not write cue points to source when source is not a wav' do
      source_mp3 = File.join(@source_dir, 'track.mp3')
      FileUtils.cp(fixture('44100.mp3'), source_mp3)

      target_mp3 = File.join(@target_dir, 'track.mp3')
      FileUtils.cp(fixture('44100.mp3'), target_mp3)

      Audio.any_instance.expects(:write_cue_points).never
      Scanner.new(@source_dir).sync(@target_dir, @device, pull_cue_points: true)
    end

    test 'sync does not write cue points to source when pull_cue_points is false' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      target_wav = File.join(@target_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), target_wav)
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Marker' }]
      CueChunk.write(target_wav, "#{target_wav}.tmp", cue_points)
      FileUtils.mv("#{target_wav}.tmp", target_wav)

      Audio.any_instance.expects(:write_cue_points).never
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync logs error when target file is missing after acid chunk write' do
      source_wav = File.join(File.expand_path(@source_dir), 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      expected_target = Pathname(File.join(File.expand_path(@target_dir), 'track.wav'))
      Audio.any_instance.stubs(:bpm).returns(120)
      AcidChunk.stubs(:write_bpm)
      Logger.expects(:log_error).with(
        instance_of(RuntimeError),
        call_site: 'Scanner#verify_written',
        arguments: { source: source_wav, target: expected_target.to_s }
      )
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync logs error when target file is missing after copy' do
      source_wav = File.join(File.expand_path(@source_dir), 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      expected_target = Pathname(File.join(File.expand_path(@target_dir), 'track.wav'))
      Audio.any_instance.stubs(:bpm).returns(nil)
      FileUtils.stubs(:install)
      Logger.expects(:log_error).with(
        instance_of(RuntimeError),
        call_site: 'Scanner#verify_written',
        arguments: { source: source_wav, target: expected_target.to_s }
      )
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync logs error when target file is missing after conversion' do
      source_aiff = File.join(File.expand_path(@source_dir), 'track.aiff')
      FileUtils.cp(fixture('44100_16.aiff'), source_aiff)

      expected_target = Pathname(File.join(File.expand_path(@target_dir), 'track.wav'))
      Audio.any_instance.stubs(:transcode).returns(true)
      Logger.expects(:log_error).with(
        instance_of(RuntimeError),
        call_site: 'Scanner#verify_written',
        arguments: { source: source_aiff, target: expected_target.to_s }
      )
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync does not log verify_written error when target file exists after write' do
      source_wav = File.join(File.expand_path(@source_dir), 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      Logger.expects(:log_error).never
      Scanner.new(@source_dir).sync(@target_dir, @device)
    end

    test 'sync copies mp3 file as-is when device supports mp3' do
      source_mp3 = File.join(@source_dir, 'track.mp3')
      FileUtils.cp(fixture('44100.mp3'), source_mp3)

      Audio.any_instance.expects(:transcode).never
      Scanner.new(@source_dir).sync(@target_dir, @device)

      target_mp3 = File.join(@target_dir, 'track.mp3')
      assert File.exist?(target_mp3)
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

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end
  end
end
