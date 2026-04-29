# frozen_string_literal: true

require 'securerandom'
require_relative '../wavesync/test_case'
require_relative '../../lib/wavesync'

module Wavesync
  class IntegrationTestCase < Wavesync::TestCase
    def self.device_model
      raise NotImplementedError, "#{self} must define .device_model"
    end

    def setup
      silence_output

      config = begin
        Wavesync::Config.load
      rescue Wavesync::ConfigError
        skip 'No wavesync config found (~/.wavesync.yml)'
      end

      device_config = config.device_configs.find { |dc| dc[:model] == self.class.device_model }
      skip "No #{self.class.device_model} device configured in ~/wavesync.yml" unless device_config
      skip "Device path not accessible: #{device_config[:path]}" unless File.exist?(device_config[:path])

      @device = Wavesync::Device.find_by(name: device_config[:model])
      @device_test_path = File.join(device_config[:path], 'wavesync_test', SecureRandom.hex(8))
      @source_dir = Dir.mktmpdir

      FileUtils.mkdir_p(@device_test_path)
    end

    def teardown
      restore_output
      FileUtils.rm_rf(@source_dir) if @source_dir
      delete_from_device(@device_test_path) if @device_test_path
    end

    private

    def source_file(dest_name, fixture:, bpm: nil, cue_points: nil)
      dest_path = File.join(@source_dir, dest_name)
      FileUtils.cp(File.join(FIXTURES_PATH, fixture), dest_path)
      audio = Wavesync::Audio.new(dest_path)
      audio.write_bpm(bpm) if bpm
      audio.write_cue_points(cue_points) if cue_points
      dest_path
    end

    def sync(pad: false, pull_cue_points: false)
      Wavesync::Scanner.new(@source_dir).sync(@device_test_path, @device, pad: pad, pull_cue_points: pull_cue_points)
    end

    def device_file(relative_path)
      File.join(@device_test_path, relative_path)
    end

    def assert_file_on_device(relative_path)
      assert File.exist?(device_file(relative_path)), "Expected file on device: #{relative_path}"
    end

    def assert_file_not_on_device(relative_path)
      refute File.exist?(device_file(relative_path)), "Expected no file on device: #{relative_path}"
    end

    def assert_acid_bpm(relative_path, expected_bpm)
      actual_bpm = Wavesync::AcidChunk.read_bpm(device_file(relative_path))
      assert_in_delta expected_bpm, actual_bpm.to_f, 0.01, "Expected ACID BPM #{expected_bpm} in #{relative_path}, got #{actual_bpm}"
    end

    def assert_no_acid_bpm(relative_path)
      actual_bpm = Wavesync::AcidChunk.read_bpm(device_file(relative_path))
      assert_nil actual_bpm, "Expected no ACID BPM in #{relative_path}, got #{actual_bpm}"
    end

    def assert_cue_points_on_device(relative_path, expected_cue_points)
      actual_cue_points = Wavesync::CueChunk.read(device_file(relative_path))
      assert_equal expected_cue_points.size, actual_cue_points.size,
                   "Expected #{expected_cue_points.size} cue point(s) in #{relative_path}, got #{actual_cue_points.size}"
      expected_cue_points.zip(actual_cue_points).each do |expected, actual|
        assert_equal expected[:sample_offset], actual[:sample_offset]
        assert_equal expected[:label], actual[:label] if expected.key?(:label)
      end
    end

    def assert_sample_rate_on_device(relative_path, expected_hz)
      actual_hz = Wavesync::Audio.new(device_file(relative_path)).sample_rate
      assert_equal expected_hz, actual_hz, "Expected sample rate #{expected_hz}Hz in #{relative_path}, got #{actual_hz}"
    end

    def assert_duration_on_device(relative_path, expected_seconds, tolerance: 0.1)
      actual_seconds = Wavesync::Audio.new(device_file(relative_path)).duration
      assert_in_delta expected_seconds, actual_seconds, tolerance,
                      "Expected duration #{expected_seconds}s in #{relative_path}, got #{actual_seconds}s"
    end

    def delete_from_device(dir_path)
      return unless File.exist?(dir_path)

      Dir.glob(File.join(dir_path, '**', '*'))
         .reverse
         .each do |entry|
           File.file?(entry) ? File.delete(entry) : Dir.rmdir(entry)
         rescue SystemCallError
           nil
         end
      Dir.rmdir(dir_path)
    rescue SystemCallError
      nil
    end
  end
end
