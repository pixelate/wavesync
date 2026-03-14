# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/config'
require_relative '../../lib/wavesync/device'
require_relative '../../lib/wavesync/ui'
require_relative '../../lib/wavesync/scanner'
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
    end

    def teardown
      ARGV.replace(@saved_argv)
    end

    test 'syncs single device without prompting' do
      @ui.expects(:select).never
      @scanner.expects(:sync).once

      CLI.start_sync
    end

    test 'syncs single device to its configured path' do
      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false)

      CLI.start_sync
    end

    test 'prompts for device selection when multiple devices are configured' do
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])
      @ui.expects(:select).with('Select device', %w[TP-7 Octatrack]).returns('TP-7')

      CLI.start_sync
    end

    test 'syncs only the selected device when multiple devices are configured' do
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])
      @ui.stubs(:select).returns('Octatrack')

      @scanner.expects(:sync).with('/tmp/ot', @device, pad: false).once

      CLI.start_sync
    end

    test 'skips prompt and uses device flag when multiple devices are configured' do
      ARGV.replace(['-d', 'TP-7'])
      @config.stubs(:device_configs).returns([DEVICE_CONFIG_A, DEVICE_CONFIG_B])

      @ui.expects(:select).never
      @scanner.expects(:sync).with('/tmp/tp7', @device, pad: false).once

      CLI.start_sync
    end

    test 'exits with error for unknown device flag' do
      ARGV.replace(['-d', 'Unknown'])

      assert_raises(SystemExit) { CLI.start_sync }
    end
  end
end
