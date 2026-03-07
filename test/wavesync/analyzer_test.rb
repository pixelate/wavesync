# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/bpm_detector'
require_relative '../../lib/wavesync/audio'
require_relative '../../lib/wavesync/acid_chunk'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/analyzer'

module Wavesync
  class AnalyzerTest < Wavesync::TestCase
    def setup
      @library_path = '/fake/library'
      @files = ['/fake/library/Artist/01 Track.wav', '/fake/library/Artist/02 Track.wav']
      Dir.stubs(:glob).returns(@files)

      @ui = stub_everything('ui')
      UI.stubs(:new).returns(@ui)

      BpmDetector.stubs(:available?).returns(true)
    end

    test 'skips files that already have BPM by default' do
      audio = stub(bpm: 120, write_bpm: nil)
      Audio.stubs(:new).returns(audio)

      audio.expects(:write_bpm).never
      BpmDetector.expects(:detect).never

      Analyzer.new(@library_path).analyze
    end

    test 'detects and writes BPM when file has no BPM' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).twice

      Analyzer.new(@library_path).analyze
    end

    test 'overwrites existing BPM when overwrite is true' do
      audio = stub(bpm: 100)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).twice

      Analyzer.new(@library_path).analyze(overwrite: true)
    end

    test 'does not write BPM when detection fails' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(nil)

      audio.expects(:write_bpm).never

      Analyzer.new(@library_path).analyze
    end

    test 'counts detected, skipped and failed correctly' do
      audio_with_bpm = stub(bpm: 100, write_bpm: nil)
      audio_without_bpm = stub(bpm: nil)

      Audio.stubs(:new).returns(audio_with_bpm, audio_without_bpm)
      BpmDetector.stubs(:detect).returns(nil)

      # one file skipped (has bpm), one file failed (no bpm detected)
      @ui.expects(:analyze_skip).once
      @ui.expects(:analyze_result).once

      Analyzer.new(@library_path).analyze
    end
  end
end
