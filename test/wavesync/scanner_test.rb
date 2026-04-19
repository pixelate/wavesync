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

    test 'sync does not copy files when log_only is true' do
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      Scanner.new(@source_dir).sync(@target_dir, @device, log_only: true)

      refute File.exist?(File.join(@target_dir, 'track.wav')), 'Expected no file to be copied in log_only mode'
    end

    test 'sync does not call system sync when log_only is true' do
      Scanner.any_instance.expects(:system).never
      Scanner.new(@source_dir).sync(@target_dir, @device, log_only: true)
    end

    test 'sync writes downbeat padding log with start and end timestamps' do
      octatrack = Device.find_by(name: 'Octatrack')
      FileConverter.any_instance.stubs(:convert).returns(true)
      Scanner.any_instance.expects(:system).with('sync')

      Scanner.new(@source_dir).sync(@target_dir, octatrack, pad: true)

      log_content = File.read(File.join(@target_dir, 'downbeat_padding.log'))
      assert_match(/\AStarted: /, log_content)
      assert_match(/Ended: .+$/, log_content)
    end

    test 'sync writes track entry with beat count to downbeat padding log' do
      octatrack = Device.find_by(name: 'Octatrack')
      source_wav = File.join(@source_dir, 'Artist/track.wav')
      FileUtils.mkdir_p(File.dirname(source_wav))
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      Audio.any_instance.stubs(:bpm).returns(120)
      BpmDetector.stubs(:available?).returns(true)
      BpmDetector.stubs(:detect_with_downbeat).returns({ bpm: 120, first_downbeat_position: 0.25 })
      FileConverter.any_instance.stubs(:convert).returns(true)
      Scanner.any_instance.expects(:system).with('sync')

      Scanner.new(@source_dir).sync(@target_dir, octatrack, pad: true)

      log_content = File.read(File.join(@target_dir, 'downbeat_padding.log'))
      assert_includes log_content, 'Artist/track.wav'
      assert_includes log_content, '3.5 beats lead-in'
    end

    test 'sync writes only start and end timestamps when no tracks need lead-in padding' do
      octatrack = Device.find_by(name: 'Octatrack')
      source_wav = File.join(@source_dir, 'track.wav')
      FileUtils.cp(fixture('44100_16.wav'), source_wav)

      Audio.any_instance.stubs(:bpm).returns(120)
      BpmDetector.stubs(:available?).returns(true)
      BpmDetector.stubs(:detect_with_downbeat).returns({ bpm: 120, first_downbeat_position: 0.0 })
      FileConverter.any_instance.stubs(:convert).returns(true)
      Scanner.any_instance.expects(:system).with('sync')

      Scanner.new(@source_dir).sync(@target_dir, octatrack, pad: true)

      log_content = File.read(File.join(@target_dir, 'downbeat_padding.log'))
      refute_includes log_content, 'beats lead-in'
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

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end
  end
end
