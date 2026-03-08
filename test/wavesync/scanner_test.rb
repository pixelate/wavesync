# frozen_string_literal: true

require 'minitest/autorun'
require 'mocha/minitest'
require 'fileutils'
require 'pathname'
require_relative 'test_case'
require_relative '../../lib/wavesync/path_resolver'
require_relative '../../lib/wavesync/device'

# Stub Audio and UI to avoid loading taglib and other heavy dependencies
module Wavesync
  class Audio
    SUPPORTED_FORMATS = %w[.m4a .mp3 .wav .aif .aiff].freeze

    def self.find_all(library_path)
      Dir.glob(File.join(library_path, '**', '*'))
         .select { |f| SUPPORTED_FORMATS.include?(File.extname(f).downcase) }
    end
  end

  class UI
    def bpm(*); end

    def file_progress(*); end

    def skip; end

    def sync_progress(*); end

    def copy(*); end

    def conversion_progress(*); end
  end
end

require_relative '../../lib/wavesync/scanner'

module Wavesync
  class ScannerTest < Wavesync::TestCase
    def setup
      @source_dir = Dir.mktmpdir
      @target_dir = Dir.mktmpdir
      @device = Device.find_by(name: 'TP-7')
      @scanner = Scanner.new(@source_dir)
      @path_resolver = PathResolver.new(@source_dir, @target_dir, @device)
    end

    def teardown
      FileUtils.rm_rf(@source_dir)
      FileUtils.rm_rf(@target_dir)
    end

    test 'convert_file skips when converted file already exists in source location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)
      source_mp3 = File.join(@source_dir, 'track.mp3')
      FileUtils.touch(source_mp3)

      audio = stub(bpm: nil)
      result = @scanner.send(:convert_file, audio, source_aiff, @path_resolver, 'mp3', 44_100, nil, 16, nil)

      assert_equal false, result
    end

    test 'convert_file does not skip when converted file does not exist in source location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)

      audio = stub(bpm: nil)
      audio.stubs(:transcode)
      FileUtils.mkdir_p(@target_dir)

      result = @scanner.send(:convert_file, audio, source_aiff, @path_resolver, 'mp3', 44_100, nil, 16, nil)

      assert_equal true, result
    end

    test 'convert_file skips when converted file already exists in target location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)
      FileUtils.mkdir_p(@target_dir)
      FileUtils.touch(File.join(@target_dir, 'track.mp3'))

      audio = stub(bpm: nil)
      result = @scanner.send(:convert_file, audio, source_aiff, @path_resolver, 'mp3', 44_100, nil, 16, nil)

      assert_equal false, result
    end
  end
end
