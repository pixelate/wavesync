# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class CLIInvocationLogTest < Wavesync::TestCase
    def setup
      silence_output
      @saved_argv = ARGV.dup
      ARGV.clear

      @library_dir = Dir.mktmpdir
      @device_dir = Dir.mktmpdir
      @config_path = File.join(@library_dir, 'wavesync_test.yml')
      template = File.read(File.join(FIXTURES_PATH, 'wavesync_test.yml'))
      File.write(@config_path, template.gsub('LIBRARY_PATH', @library_dir).gsub('DEVICE_PATH', @device_dir))

      Scanner.any_instance.stubs(:system)
    end

    def teardown
      restore_output
      ARGV.replace(@saved_argv)
      Logger.configure(nil)
      FileUtils.rm_rf(@library_dir)
      FileUtils.rm_rf(@device_dir)
    end

    def log_path
      File.join(@library_dir, 'wavesync.log')
    end

    test 'sync command writes invocation to library log' do
      ARGV.replace(['sync', '--config', @config_path])
      CLI.start

      assert File.exist?(log_path)
      assert_match(/wavesync sync --config/, File.read(log_path))
    end

    test 'analyze command writes invocation to library log' do
      BpmDetector.stubs(:available?).returns(true)
      UI.any_instance.stubs(:confirm).returns(true)

      ARGV.replace(['analyze', '--config', @config_path])
      CLI.start

      assert File.exist?(log_path)
      assert_match(/wavesync analyze --config/, File.read(log_path))
    end
  end
end
