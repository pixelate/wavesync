# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class ClearCacheTest < Wavesync::TestCase
    def setup
      @saved_argv = ARGV.dup
      ARGV.clear
      @cache_root = Dir.mktmpdir
    end

    def teardown
      ARGV.replace(@saved_argv)
      FileUtils.rm_rf(@cache_root)
      Logger.configure(nil)
    end

    test 'clears the cache for each MTP device and prints sizes' do
      configure(devices: [
                  { name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' },
                  { name: 'TP-7 Backup', model: 'TP-7', path: 'library', transport: 'mtp' }
                ])
      stub_cache_path('TP-7', 'tp-7')
      stub_cache_path('TP-7 Backup', 'tp-7_backup')
      seed_cache('tp-7', 'a.wav' => 'a' * 100)
      seed_cache('tp-7_backup', 'b.wav' => 'b' * 200)

      output = capture_stdout { Commands::ClearCache.new.run }

      assert_match(/Cleared .*tp-7 \(100 B\)/, output)
      assert_match(/Cleared .*tp-7_backup \(200 B\)/, output)
      refute File.exist?(File.join(@cache_root, 'tp-7'))
      refute File.exist?(File.join(@cache_root, 'tp-7_backup'))
    end

    test 'clears only the specified device when -d is given' do
      configure(devices: [
                  { name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' },
                  { name: 'TP-7 Backup', model: 'TP-7', path: 'library', transport: 'mtp' }
                ])
      stub_cache_path('TP-7', 'tp-7')
      stub_cache_path('TP-7 Backup', 'tp-7_backup')
      seed_cache('tp-7', 'a.wav' => 'a')
      seed_cache('tp-7_backup', 'b.wav' => 'b')

      ARGV.replace(['-d', 'TP-7'])
      capture_stdout { Commands::ClearCache.new.run }

      refute File.exist?(File.join(@cache_root, 'tp-7'))
      assert File.exist?(File.join(@cache_root, 'tp-7_backup'))
    end

    test 'reports when there is no cache to clear' do
      configure(devices: [{ name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' }])
      stub_cache_path('TP-7', 'tp-7')

      output = capture_stdout { Commands::ClearCache.new.run }

      assert_match(/No cache for TP-7/, output)
    end

    test 'reports when no MTP devices are configured' do
      configure(devices: [{ name: 'OT', model: 'Octatrack', path: '/tmp/ot' }])

      output = capture_stdout { Commands::ClearCache.new.run }

      assert_match(/No MTP devices configured/, output)
    end

    test 'exits with error when -d names an unknown device' do
      configure(devices: [{ name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' }])

      ARGV.replace(['-d', 'Unknown'])
      assert_raises(SystemExit) { capture_stdout { Commands::ClearCache.new.run } }
    end

    test 'reports kilobyte sizes' do
      configure(devices: [{ name: 'TP-7', model: 'TP-7', path: 'library', transport: 'mtp' }])
      stub_cache_path('TP-7', 'tp-7')
      seed_cache('tp-7', 'big.wav' => 'x' * 2048)

      output = capture_stdout { Commands::ClearCache.new.run }

      assert_match(/2\.0 KB/, output)
    end

    private

    def configure(devices:)
      data = { 'library' => Dir.mktmpdir, 'devices' => devices.map { |hash| hash.transform_keys(&:to_s) } }
      config = Wavesync::Config.new(data)
      Wavesync::Config.stubs(:load).returns(config)
      Logger.stubs(:configure)
      Logger.stubs(:log_invocation)
    end

    def stub_cache_path(device_name, directory_name)
      Wavesync::Transport::Mtp.stubs(:cache_path).with(device_name).returns(File.join(@cache_root, directory_name))
    end

    def seed_cache(directory_name, files)
      base = File.join(@cache_root, directory_name)
      FileUtils.mkdir_p(base)
      files.each do |relative_path, content|
        File.binwrite(File.join(base, relative_path), content)
      end
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end
  end
end
