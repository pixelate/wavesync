# frozen_string_literal: true

require 'tempfile'
require_relative 'test_case'
require_relative '../../lib/wavesync/ffmpeg'

module Wavesync
  class FFMPEGTest < Wavesync::TestCase
    test 'binary returns the path to the ffmpeg executable' do
      assert_match(/ffmpeg/, FFMPEG.binary)
    end

    test 'ffplay_binary returns the path to the ffplay executable' do
      assert_match(/ffplay/, FFMPEG.ffplay_binary)
    end

    test 'builder methods return self for chaining' do
      command = FFMPEG.new
      assert_same command, command.input('file.wav')
      assert_same command, command.audio_codec('pcm_s16le')
      assert_same command, command.sample_rate(44_100)
      assert_same command, command.audio_filter('volume=0.5')
      assert_same command, command.filter_complex('anull')
      assert_same command, command.output_format('wav')
      assert_same command, command.duration(1.0)
    end

    test 'run transcodes a file to the output path' do
      with_output('wav') do |output_path|
        FFMPEG.new.input(fixture('44100_16.wav')).run(output_path)

        assert File.exist?(output_path)
      end
    end

    test 'run applies audio_codec' do
      with_output('wav') do |output_path|
        FFMPEG.new
              .input(fixture('44100_24.wav'))
              .audio_codec('pcm_s16le')
              .run(output_path)

        assert_equal 16, FFMPEG::Probe.new(output_path).bit_depth
      end
    end

    test 'run applies sample_rate' do
      with_output('wav') do |output_path|
        FFMPEG.new
              .input(fixture('44100_16.wav'))
              .audio_codec('pcm_s16le')
              .sample_rate(22_050)
              .run(output_path)

        assert_equal 22_050, FFMPEG::Probe.new(output_path).sample_rate
      end
    end

    test 'run with lavfi input generates audio of the expected duration' do
      with_output('wav') do |output_path|
        FFMPEG.new
              .input('sine=frequency=440:sample_rate=44100:duration=1', format: 'lavfi')
              .audio_codec('pcm_s16le')
              .run(output_path)

        assert_in_delta 1.0, FFMPEG::Probe.new(output_path).duration, 0.1
      end
    end

    test 'run raises Error when ffmpeg fails' do
      assert_raises(FFMPEG::Error) do
        FFMPEG.new.input('/nonexistent/file.wav').run('/tmp/out.wav')
      end
    end

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end

    def with_output(ext)
      tmp = Tempfile.new(['ffmpeg_test', ".#{ext}"])
      tmp.close
      yield tmp.path
    ensure
      tmp&.unlink
    end
  end
end
