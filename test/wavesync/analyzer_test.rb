# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/logger'
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
      @ui.stubs(:confirm).returns(true)
      UI.stubs(:new).returns(@ui)

      BpmDetector.stubs(:available?).returns(true)

      Logger.stubs(:configure)
      Logger.stubs(:log_run_time)
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

    test 'asks for confirmation before processing files' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)
      audio.stubs(:write_bpm)

      @ui.expects(:confirm).once.returns(true)

      Analyzer.new(@library_path).analyze
    end

    test 'confirmation message refers to the library when no path is given' do
      audio = stub(bpm: nil, write_bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      @ui.expects(:confirm).with(regexp_matches(/files in library/)).returns(false)

      Analyzer.new(@library_path).analyze
    end

    test 'confirmation message refers to a folder when a folder path is given' do
      folder_path = '/fake/library/Artist'
      File.stubs(:directory?).with(folder_path).returns(true)

      @ui.expects(:confirm).with(regexp_matches(/files in folder/)).returns(false)

      Analyzer.new(@library_path).analyze(path: folder_path)
    end

    test 'confirmation message refers to a single file when a file path is given' do
      @ui.expects(:confirm).with(regexp_matches(/add bpm meta data to file\./)).returns(false)

      Analyzer.new(@library_path).analyze(path: '/fake/library/Artist/01 Track.wav')
    end

    test 'stops analyzing when user declines confirmation' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)

      @ui.stubs(:confirm).returns(false)
      BpmDetector.expects(:detect).never
      audio.expects(:write_bpm).never

      Analyzer.new(@library_path).analyze
    end

    test 'logs run time after processing files' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)
      audio.stubs(:write_bpm)

      Logger.expects(:log_run_time).once

      Analyzer.new(@library_path).analyze
    end

    test 'does not log run time when user declines confirmation' do
      @ui.stubs(:confirm).returns(false)

      Logger.expects(:log_run_time).never

      Analyzer.new(@library_path).analyze
    end

    test 'analyzes only the given file when a file path is provided' do
      audio = stub(bpm: nil)
      Audio.stubs(:new).with('/fake/library/Artist/01 Track.wav').returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).once

      Analyzer.new(@library_path).analyze(path: '/fake/library/Artist/01 Track.wav')
    end

    test 'expands the given path before analyzing' do
      relative_path = 'Artist/01 Track.wav'
      expanded_path = File.expand_path(relative_path)
      audio = stub(bpm: nil, write_bpm: nil)

      Audio.expects(:new).with(expanded_path).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      Analyzer.new(@library_path).analyze(path: relative_path)
    end

    test 'ignores other library files when a file path is provided' do
      audio = stub(bpm: nil, write_bpm: nil)
      Audio.expects(:new).with('/fake/library/Artist/01 Track.wav').once.returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      Analyzer.new(@library_path).analyze(path: '/fake/library/Artist/01 Track.wav')
    end

    test 'analyzes all audio files in the folder when a folder path is provided' do
      folder_path = '/fake/library/Artist'
      File.stubs(:directory?).with(folder_path).returns(true)

      audio = stub(bpm: nil)
      Audio.stubs(:new).returns(audio)
      BpmDetector.stubs(:detect).returns(120)

      audio.expects(:write_bpm).with(120).twice

      Analyzer.new(@library_path).analyze(path: folder_path)
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
