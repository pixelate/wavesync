# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/bpm_detector'
require_relative '../../lib/wavesync/audio'
require_relative '../../lib/wavesync/acid_chunk'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/library'
require_relative '../../lib/wavesync/analyzer'

module Wavesync
  class AnalyzerTest < Wavesync::TestCase
    def setup
      @library_path = '/fake/library'
      @files = ['/fake/library/Artist/01 Track.wav', '/fake/library/Artist/02 Track.wav']
      Dir.stubs(:glob).returns(@files)

      @ui = stub_everything('ui')
      UI.stubs(:new).returns(@ui)

      @library = stub_everything('library')
      Library.stubs(:load).returns(@library)

      BpmDetector.stubs(:available?).returns(true)
    end

    test 'skips files that already have BPM by default' do
      audio = stub(bpm: 120, write_bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)

      audio.expects(:write_bpm).never
      BpmDetector.expects(:detect).never

      Analyzer.new(@library_path).analyze
    end

    test 'detects and writes BPM when file has no BPM' do
      audio = stub(bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).twice

      Analyzer.new(@library_path).analyze
    end

    test 'overwrites existing BPM when overwrite is true' do
      audio = stub(bpm: 100, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).twice

      Analyzer.new(@library_path).analyze(overwrite: true)
    end

    test 'does not write BPM when detection fails' do
      audio = stub(bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(nil)

      audio.expects(:write_bpm).never

      Analyzer.new(@library_path).analyze
    end

    test 'counts detected, skipped and failed correctly' do
      audio_with_bpm = stub(bpm: 100, write_bpm: nil, duration: 240.0, length: '4:00')
      audio_without_bpm = stub(bpm: nil, duration: 240.0, length: '4:00')

      Audio.stubs(:new).returns(audio_with_bpm, audio_without_bpm)
      BpmDetector.stubs(:detect).returns(nil)

      # one file skipped (has bpm), one file failed (no bpm detected)
      @ui.expects(:analyze_skip).once
      @ui.expects(:analyze_result).once

      Analyzer.new(@library_path).analyze
    end

    test 'updates library with length and bars for files with existing BPM' do
      audio = stub(bpm: 120, write_bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)

      @library.expects(:update_track).with(
        'Artist/01 Track.wav', length: '4:00', bars: 128
      )
      @library.expects(:update_track).with(
        'Artist/02 Track.wav', length: '4:00', bars: 128
      )
      @library.expects(:save)

      Analyzer.new(@library_path).analyze
    end

    test 'updates library with length and bars after detecting BPM' do
      audio = stub(bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)
      audio.stubs(:write_bpm)

      @library.expects(:update_track).twice
      @library.expects(:save)

      Analyzer.new(@library_path).analyze
    end

    test 'computes correct number of bars' do
      # 120 bpm, 240 seconds => 240 * 120 / 240 = 128 bars
      audio = stub(bpm: 120, write_bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)

      captured = []
      @library.stubs(:update_track) { |_path, **kwargs| captured << kwargs[:bars] }
      @library.stubs(:save)

      Analyzer.new(@library_path).analyze

      assert_equal [128, 128], captured
    end

    test 'does not update library when BPM detection fails' do
      audio = stub(bpm: nil, duration: 240.0, length: '4:00')
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(nil)

      @library.expects(:update_track).never
      @library.expects(:save)

      Analyzer.new(@library_path).analyze
    end
  end
end
