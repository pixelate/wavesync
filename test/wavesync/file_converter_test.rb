# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/audio_format'
require_relative '../../lib/wavesync/file_converter'
require_relative '../../lib/wavesync/path_resolver'
require_relative '../../lib/wavesync/device'

module Wavesync
  class FileConverterTest < Wavesync::TestCase
    def setup
      @source_dir = Dir.mktmpdir
      @target_dir = Dir.mktmpdir
      @device = Device.find_by(name: 'TP-7')

      @converter = FileConverter.new
      @path_resolver = PathResolver.new(@source_dir, @target_dir, @device)
    end

    def teardown
      FileUtils.rm_rf(@source_dir)
      FileUtils.rm_rf(@target_dir)
    end

    test 'convert skips when converted file already exists in source location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)
      FileUtils.touch(File.join(@source_dir, 'track.mp3'))

      audio = stub(bpm: nil)
      source_format = AudioFormat.new(file_type: 'aiff', sample_rate: 44_100, bit_depth: 16)
      target_format = AudioFormat.new(file_type: 'mp3', sample_rate: nil, bit_depth: nil)
      result = @converter.convert(audio, source_aiff, @path_resolver, source_format, target_format)

      assert_equal false, result
    end

    test 'convert does not skip when converted file does not exist in source location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)

      audio = stub(bpm: nil)
      audio.stubs(:transcode)

      source_format = AudioFormat.new(file_type: 'aiff', sample_rate: 44_100, bit_depth: 16)
      target_format = AudioFormat.new(file_type: 'mp3', sample_rate: nil, bit_depth: nil)
      result = @converter.convert(audio, source_aiff, @path_resolver, source_format, target_format)

      assert_equal true, result
    end

    test 'convert skips when converted file already exists in target location' do
      source_aiff = File.join(@source_dir, 'track.aiff')
      FileUtils.touch(source_aiff)
      FileUtils.touch(File.join(@target_dir, 'TRACK.MP3'))

      Audio.any_instance.stubs(:duration).returns(0)
      audio = stub(bpm: nil, duration: 0)
      source_format = AudioFormat.new(file_type: 'aiff', sample_rate: 44_100, bit_depth: 16)
      target_format = AudioFormat.new(file_type: 'mp3', sample_rate: nil, bit_depth: nil)
      result = @converter.convert(audio, source_aiff, @path_resolver, source_format, target_format)

      assert_equal false, result
    end
  end
end
