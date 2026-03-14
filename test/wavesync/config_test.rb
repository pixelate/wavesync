# frozen_string_literal: true

require 'tempfile'
require_relative 'test_case'
require_relative '../../lib/wavesync/config'

module Wavesync
  class ConfigTest < Wavesync::TestCase
    VALID_CONFIG = {
      'library' => '/tmp/library',
      'devices' => [
        { 'name' => 'My Device', 'model' => 'TP-7', 'path' => '/tmp/device' }
      ]
    }.freeze

    test 'load raises ConfigError when file does not exist' do
      error = assert_raises(ConfigError) { Config.load('/nonexistent/path/wavesync.yml') }
      assert_match 'Config file not found', error.message
    end

    test 'load raises ConfigError for malformed YAML' do
      file = Tempfile.new(['wavesync', '.yml'])
      file.write("library: /tmp\ndevices: [\nbad yaml{{")
      file.close
      error = assert_raises(ConfigError) { Config.load(file.path) }
      assert_match 'Invalid YAML in config file', error.message
    ensure
      file.unlink
    end

    test 'load succeeds with valid config file' do
      file = Tempfile.new(['wavesync', '.yml'])
      file.write("library: /tmp\ndevices:\n  - name: My Device\n    model: TP-7\n    path: /tmp/device\n")
      file.close
      config = Config.load(file.path)
      assert_equal File.expand_path('/tmp'), config.library
    ensure
      file.unlink
    end

    test 'raises ConfigError when YAML root is not a hash' do
      error = assert_raises(ConfigError) { Config.new(['not', 'a', 'hash']) }
      assert_match 'must contain a YAML mapping', error.message
    end

    test 'raises ConfigError when YAML root is nil' do
      error = assert_raises(ConfigError) { Config.new(nil) }
      assert_match 'must contain a YAML mapping', error.message
    end

    test 'raises ConfigError for unsupported top-level keys' do
      data = VALID_CONFIG.merge('unknown_key' => 'value')
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match 'Unsupported config keys', error.message
      assert_match 'unknown_key', error.message
    end

    test 'raises ConfigError when library key is missing' do
      data = VALID_CONFIG.reject { |k, _| k == 'library' }
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Missing required config key: 'library'", error.message
    end

    test 'raises ConfigError when devices key is missing' do
      data = VALID_CONFIG.reject { |k, _| k == 'devices' }
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Missing required config key: 'devices'", error.message
    end

    test 'raises ConfigError when library is not a string' do
      data = VALID_CONFIG.merge('library' => ['not', 'a', 'string'])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "'library' must be a string", error.message
    end

    test 'raises ConfigError when devices is not an array' do
      data = VALID_CONFIG.merge('devices' => 'not an array')
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "'devices' must be a list", error.message
    end

    test 'raises ConfigError when devices is empty' do
      data = VALID_CONFIG.merge('devices' => [])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "'devices' must contain at least one device", error.message
    end

    test 'raises ConfigError when a device entry is not a hash' do
      data = VALID_CONFIG.merge('devices' => ['not a hash'])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match 'Device 1 must be a YAML mapping', error.message
    end

    test 'raises ConfigError for unsupported device keys' do
      device = { 'name' => 'My Device', 'model' => 'TP-7', 'path' => '/tmp', 'extra' => 'bad' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match 'Unsupported keys in device 1', error.message
      assert_match 'extra', error.message
    end

    test 'raises ConfigError when device name is missing' do
      device = { 'model' => 'TP-7', 'path' => '/tmp' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Missing required key 'name' in device 1", error.message
    end

    test 'raises ConfigError when device model is missing' do
      device = { 'name' => 'My Device', 'path' => '/tmp' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Missing required key 'model' in device 1", error.message
    end

    test 'raises ConfigError when device path is missing' do
      device = { 'name' => 'My Device', 'model' => 'TP-7' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Missing required key 'path' in device 1", error.message
    end

    test 'raises ConfigError when device name is not a string' do
      device = { 'name' => 123, 'model' => 'TP-7', 'path' => '/tmp' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Device 1 'name' must be a string", error.message
    end

    test 'raises ConfigError when device model is not a string' do
      device = { 'name' => 'My Device', 'model' => ['TP-7'], 'path' => '/tmp' }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Device 1 'model' must be a string", error.message
    end

    test 'raises ConfigError when device path is not a string' do
      device = { 'name' => 'My Device', 'model' => 'TP-7', 'path' => { 'bad' => 'type' } }
      data = VALID_CONFIG.merge('devices' => [device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match "Device 1 'path' must be a string", error.message
    end

    test 'error message references correct device index for second device' do
      valid_device = { 'name' => 'First', 'model' => 'TP-7', 'path' => '/tmp' }
      bad_device = { 'name' => 'Second', 'model' => 'TP-7' }
      data = VALID_CONFIG.merge('devices' => [valid_device, bad_device])
      error = assert_raises(ConfigError) { Config.new(data) }
      assert_match 'device 2', error.message
    end

    test 'initializes with valid data' do
      config = Config.new(VALID_CONFIG)
      assert_equal File.expand_path('/tmp/library'), config.library
      assert_equal 1, config.device_configs.size
      assert_equal 'My Device', config.device_configs.first[:name]
      assert_equal 'TP-7', config.device_configs.first[:model]
      assert_equal File.expand_path('/tmp/device'), config.device_configs.first[:path]
    end

    test 'initializes with multiple devices' do
      data = VALID_CONFIG.merge('devices' => [
                                  { 'name' => 'Device A', 'model' => 'TP-7', 'path' => '/tmp/a' },
                                  { 'name' => 'Device B', 'model' => 'Octatrack', 'path' => '/tmp/b' }
                                ])
      config = Config.new(data)
      assert_equal 2, config.device_configs.size
    end
  end
end
