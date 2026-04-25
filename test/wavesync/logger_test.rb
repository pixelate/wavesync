# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative 'test_case'
require_relative '../../lib/wavesync/logger'

module Wavesync
  class LoggerTest < Wavesync::TestCase
    def setup
      @tmp_dir = Dir.mktmpdir
      Logger.configure(@tmp_dir)
    end

    def teardown
      Logger.configure(nil)
      FileUtils.rm_rf(@tmp_dir)
    end

    def log_path
      File.join(@tmp_dir, 'wavesync.log')
    end

    test 'configure sets log path inside library directory' do
      assert_equal log_path, Logger.log_path
    end

    test 'log writes to the configured library path' do
      Logger.log_error(RuntimeError.new('oops'), call_site: 'Foo#bar', arguments: {})

      assert File.exist?(log_path)
    end

    test 'log appends an entry to the log file' do
      error = RuntimeError.new('something went wrong')
      Logger.log_error(error, call_site: 'Foo#bar', arguments: { file_path: '/tmp/track.wav' })

      entry = File.read(log_path)
      assert_match(%r{Foo#bar\(file_path: "/tmp/track\.wav"\) raised RuntimeError: something went wrong}, entry)
    end

    test 'log includes a timestamp in ISO 8601 format' do
      Logger.log_error(RuntimeError.new('oops'), call_site: 'Foo#bar', arguments: {})

      entry = File.read(log_path)
      assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/, entry)
    end

    test 'log appends multiple entries without truncating' do
      Logger.log_error(RuntimeError.new('first'), call_site: 'A#b', arguments: {})
      Logger.log_error(RuntimeError.new('second'), call_site: 'C#d', arguments: {})

      lines = File.readlines(log_path)
      assert_equal 2, lines.size
      assert_match(/first/, lines[0])
      assert_match(/second/, lines[1])
    end

    test 'log formats multiple arguments correctly' do
      Logger.log_error(RuntimeError.new('fail'), call_site: 'Foo#bar', arguments: { source: '/a.wav', target: '/b.wav' })

      entry = File.read(log_path)
      assert_match(%r{source: "/a\.wav", target: "/b\.wav"}, entry)
    end

    test 'log works with no arguments' do
      Logger.log_error(RuntimeError.new('fail'), call_site: 'Foo#bar')

      entry = File.read(log_path)
      assert_match(/Foo#bar\(\) raised RuntimeError: fail/, entry)
    end

    test 'log does nothing when not configured' do
      Logger.configure(nil)
      Logger.log_error(RuntimeError.new('fail'), call_site: 'Foo#bar')

      assert_equal false, File.exist?(log_path)
    end

    test 'log_invocation writes a divider and the wavesync invocation' do
      Logger.capture_invocation(['sync', '--device', 'Octatrack'])
      Logger.log_invocation

      entry = File.read(log_path)
      assert_match(/\A---\n/, entry)
      assert_match(/wavesync sync --device Octatrack/, entry)
    end

    test 'log_invocation includes a timestamp' do
      Logger.capture_invocation(['sync'])
      Logger.log_invocation

      entry = File.read(log_path)
      assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] wavesync sync/, entry)
    end

    test 'log_invocation does nothing when not configured' do
      Logger.configure(nil)
      Logger.capture_invocation(['sync'])
      Logger.log_invocation

      assert_equal false, File.exist?(log_path)
    end

    test 'log_invocation writes invocation when configure is called after capture' do
      Logger.capture_invocation(['sync', '--device', 'Octatrack'])
      Logger.configure(@tmp_dir)
      Logger.log_invocation

      entry = File.read(log_path)
      assert_match(/wavesync sync --device Octatrack/, entry)
    end

    test 'log_invocation writes analyze invocation when configure is called after capture' do
      Logger.capture_invocation(['analyze', '--force'])
      Logger.configure(@tmp_dir)
      Logger.log_invocation

      entry = File.read(log_path)
      assert_match(/wavesync analyze --force/, entry)
    end

    test 'log_invocation does nothing when no invocation was captured' do
      Logger.log_invocation

      assert_equal false, File.exist?(log_path)
    end

    test 'log_invocation clears captured args so it only logs once' do
      Logger.capture_invocation(['sync'])
      Logger.log_invocation
      Logger.log_invocation

      lines = File.readlines(log_path)
      assert_equal 2, lines.size
    end

    test 'invocation divider appears above error entries in the same run' do
      Logger.capture_invocation(['sync'])
      Logger.log_invocation
      Logger.log_error(RuntimeError.new('oops'), call_site: 'Foo#bar')

      lines = File.readlines(log_path)
      assert_equal '---', lines[0].chomp
      assert_match(/wavesync sync/, lines[1])
      assert_match(/Foo#bar/, lines[2])
    end

    test 'log_run_time formats seconds only' do
      Logger.log_run_time(45.9)

      entry = File.read(log_path)
      assert_match(/Run time: 45s/, entry)
    end

    test 'log_run_time formats minutes and seconds' do
      Logger.log_run_time(245)

      entry = File.read(log_path)
      assert_match(/Run time: 4m 5s/, entry)
    end

    test 'log_run_time formats hours, minutes and seconds' do
      Logger.log_run_time(5025)

      entry = File.read(log_path)
      assert_match(/Run time: 1h 23m 45s/, entry)
    end

    test 'log_run_time includes a timestamp' do
      Logger.log_run_time(5.0)

      entry = File.read(log_path)
      assert_match(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] Run time:/, entry)
    end

    test 'log_run_time does nothing when not configured' do
      Logger.configure(nil)
      Logger.log_run_time(5.0)

      assert_equal false, File.exist?(log_path)
    end

    test 'log_run_time appends entry without truncating existing log' do
      Logger.log_error(RuntimeError.new('oops'), call_site: 'Foo#bar')
      Logger.log_run_time(3.0)

      lines = File.readlines(log_path)
      assert_equal 2, lines.size
      assert_match(/Foo#bar/, lines[0])
      assert_match(/Run time:/, lines[1])
    end
  end
end
