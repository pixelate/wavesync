# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/config'
require_relative '../../lib/wavesync/device'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/scanner'
require_relative '../../lib/wavesync/commands'
require_relative '../../lib/wavesync/cli'

module Wavesync
  class CLITest < Wavesync::TestCase
    DEVICE_CONFIG_A = { name: 'TP-7', model: 'TP-7', path: '/tmp/tp7' }.freeze
    DEVICE_CONFIG_B = { name: 'Octatrack', model: 'Octatrack', path: '/tmp/ot' }.freeze

    def setup
      @saved_argv = ARGV.dup
      ARGV.clear

      @config = stub(library: '/tmp/library', device_configs: [DEVICE_CONFIG_A])
      Config.stubs(:load).returns(@config)

      @device = stub('device')
      Device.stubs(:find_by).returns(@device)

      @scanner = stub('scanner', sync: nil)
      Scanner.stubs(:new).returns(@scanner)

      @ui = stub_everything('ui')
      UI.stubs(:new).returns(@ui)

      Logger.stubs(:capture_invocation)
      Logger.stubs(:configure)
      Logger.stubs(:log_invocation)
    end

    def teardown
      ARGV.replace(@saved_argv)
    end

    test 'start captures invocation args before processing' do
      ARGV.replace(['sync', '--device', 'TP-7'])
      Logger.expects(:capture_invocation).with(['sync', '--device', 'TP-7'])
      CLI.start
    end

    test 'parse_options configures error logger with library path' do
      Logger.expects(:configure).with('/tmp/library')
      Commands::Sync.new.run
    end

    test 'parse_options logs invocation' do
      Logger.expects(:log_invocation)
      Commands::Sync.new.run
    end

    test 'syncs single device without prompting' do
      @ui.expects(:select).never
      @scanner.expects(:sync).once

      Commands::Sync.new.run
    end

    test 'syncs single device to its configured path' do
      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false, sync_throttle: nil)

      Commands::Sync.new.run
    end

    test 'prompts for device selection when multiple devices are configured' do
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])
      @ui.expects(:select).with('Select device', %w[TP-7 Octatrack]).returns('TP-7')

      Commands::Sync.new.run
    end

    test 'syncs only the selected device when multiple devices are configured' do
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])
      @ui.stubs(:select).returns('Octatrack')

      @scanner.expects(:sync).with('/tmp/ot', @device, pad: false, sync_throttle: nil).once

      Commands::Sync.new.run
    end

    test 'skips prompt and uses device flag when multiple devices are configured' do
      ARGV.replace(['-d', 'TP-7'])
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])

      @ui.expects(:select).never
      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false, sync_throttle: nil).once

      Commands::Sync.new.run
    end

    test 'passes sync_throttle mode to scanner when --sync-throttle option is given' do
      ARGV.replace(['--sync-throttle', 'disk_space'])

      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false, sync_throttle: :disk_space).once

      Commands::Sync.new.run
    end

    test 'passes fixed_delay throttle mode to scanner' do
      ARGV.replace(['--sync-throttle', 'fixed_delay'])

      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false, sync_throttle: :fixed_delay).once

      Commands::Sync.new.run
    end

    test 'passes lsof throttle mode to scanner' do
      ARGV.replace(['--sync-throttle', 'lsof'])

      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false, sync_throttle: :lsof).once

      Commands::Sync.new.run
    end

    test 'exits with error for unknown sync throttle mode' do
      ARGV.replace(['--sync-throttle', 'unknown_mode'])

      assert_raises(SystemExit) { Commands::Sync.new.run }
    end

    test 'exits with error for unknown device flag' do
      ARGV.replace(['-d', 'Unknown'])

      assert_raises(SystemExit) { Commands::Sync.new.run }
    end

    test 'prints help when help command is given' do
      ARGV.replace(['help'])

      output = capture_io { CLI.start }.first

      assert_includes output, 'sync'
      assert_includes output, 'analyze'
      assert_includes output, 'set'
      assert_includes output, 'help'
    end

    test 'help output includes usage line' do
      output = capture_io { Commands::Help.new.run }.first

      assert_includes output, 'Usage: wavesync'
    end

    test 'help output includes options section' do
      output = capture_io { Commands::Help.new.run }.first

      assert_includes output, 'Options:'
    end
  end
end
