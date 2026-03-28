# frozen_string_literal: true

require 'yaml'
require_relative 'test_case'
require_relative '../../lib/wavesync/audio_format'
require_relative '../../lib/wavesync/device'

module Wavesync
  class DeviceTest < Wavesync::TestCase
    test 'initialization sets attributes' do
      device = Device.new(
        name: 'Test',
        sample_rates: [44_100],
        file_types: ['wav'],
        bit_depths: [16]
      )
      assert_equal 'Test', device.name
      assert_equal [44_100], device.sample_rates
      assert_equal ['wav'], device.file_types
      assert_equal [16], device.bit_depths
    end

    test '#all loads devices from YAML' do
      devices = Device.all
      assert_equal 2, devices.size
      names = devices.map(&:name)
      assert_includes names, 'TP-7'
      assert_includes names, 'Octatrack'
    end

    test '#load_from_yaml creates device objects' do
      devices = Device.load_from_yaml
      assert(devices.all?(Device))
    end

    test 'TP-7 device attributes are correct' do
      tp7 = Device.find_by(name: 'TP-7')
      refute_nil tp7
      assert_equal [22_050, 44_100, 48_000, 88_200, 96_000], tp7.sample_rates
      assert_equal %w[wav mp3], tp7.file_types
    end

    test 'TP-7 has tm sign as unsupported character' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_equal ['™'], tp7.unsupported_characters
    end

    test 'Octatrack device attributes are correct' do
      octatrack = Device.find_by(name: 'Octatrack')
      refute_nil octatrack
      assert_equal [44_100], octatrack.sample_rates
      assert_equal %w[wav aiff aif], octatrack.file_types
    end

    test 'Octatrack has tm sign as unsupported character' do
      octatrack = Device.find_by(name: 'Octatrack')
      assert_equal ['™'], octatrack.unsupported_characters
    end

    test 'unsupported_characters defaults to empty array' do
      device = Device.new(
        name: 'Test',
        sample_rates: [44_100],
        file_types: ['wav'],
        bit_depths: [16]
      )
      assert_equal [], device.unsupported_characters
    end

    test '#find_by returns nil for unknown device' do
      assert_nil Device.find_by(name: 'Non-exist-ent')
    end

    test '.target_file_type returns nil when source format is supported' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_nil tp7.target_file_type('song.wav')
    end

    test '.target_file_type returns first supported format when source is unsupported' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_equal 'wav', tp7.target_file_type('song.aiff')
    end

    test '.target_file_type handles uppercase extensions' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_nil tp7.target_file_type('SONG.WAV')
      assert_equal 'wav', tp7.target_file_type('SONG.AIFF')
    end

    test '.target_sample_rate returns nil when source rate is supported' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_nil tp7.target_sample_rate(44_100)
      assert_nil tp7.target_sample_rate(48_000)
      assert_nil tp7.target_sample_rate(88_200)
      assert_nil tp7.target_sample_rate(96_000)
    end

    test '.target_sample_rate returns closest supported rate' do
      octatrack = Device.find_by(name: 'Octatrack')
      assert_equal 44_100, octatrack.target_sample_rate(32_000)
      assert_equal 44_100, octatrack.target_sample_rate(48_000)
      assert_equal 44_100, octatrack.target_sample_rate(96_000)

      tp7 = Device.find_by(name: 'TP-7')
      assert_equal 96_000, tp7.target_sample_rate(192_000)
    end

    test '.target_bit_depth returns nil when source bit depth is nil' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_nil tp7.target_bit_depth(nil)
    end

    test '.target_bit_depth returns nil when source bit depth is supported' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_nil tp7.target_bit_depth(8)
      assert_nil tp7.target_bit_depth(16)
      assert_nil tp7.target_bit_depth(24)
    end

    test '.target_format returns all nils when source format is fully supported' do
      tp7 = Device.find_by(name: 'TP-7')
      source_format = AudioFormat.new(file_type: 'wav', sample_rate: 44_100, bit_depth: 24)
      target_format = tp7.target_format(source_format, 'song.wav')
      assert_nil target_format.file_type
      assert_nil target_format.sample_rate
      assert_nil target_format.bit_depth
    end

    test '.target_format returns converted values when source format is unsupported' do
      octatrack = Device.find_by(name: 'Octatrack')
      source_format = AudioFormat.new(file_type: 'mp3', sample_rate: 96_000, bit_depth: 32)
      target_format = octatrack.target_format(source_format, 'song.mp3')
      assert_equal 'wav', target_format.file_type
      assert_equal 44_100, target_format.sample_rate
      assert_equal 24, target_format.bit_depth
    end

    test '.target_bit_depth returns closest supported bit depth' do
      tp7 = Device.find_by(name: 'TP-7')
      assert_equal 16, tp7.target_bit_depth(12)
      assert_equal 24, tp7.target_bit_depth(20)
      assert_equal 24, tp7.target_bit_depth(32)
    end
  end
end
