# frozen_string_literal: true

require_relative 'integration_test_case'

module Wavesync
  class OctatrackSyncTest < IntegrationTestCase
    def self.device_model = 'Octatrack'

    test 'copies wav without bpm using original filename' do
      source_file('track.wav', fixture: '44100_16.wav')
      sync
      assert_file_on_device 'track.wav'
    end

    test 'copies wav with bpm, bpm appended to filename' do
      source_file('track.wav', fixture: '44100_16.wav', bpm: 120)
      sync
      assert_file_on_device 'track 120 bpm.wav'
      assert_file_not_on_device 'track.wav'
    end

    test 'copies aif without bpm using original filename' do
      source_file('track.aif', fixture: '44100_16.aif')
      sync
      assert_file_on_device 'track.aif'
    end

    test 'copies aif with bpm, bpm appended to filename' do
      source_file('track.aif', fixture: '44100_16.aif', bpm: 130)
      sync
      assert_file_on_device 'track 130 bpm.aif'
      assert_file_not_on_device 'track.aif'
    end

    test 'converts wav at 48000hz to 44100hz' do
      source_file('track.wav', fixture: '48000_16.wav')
      sync
      assert_file_on_device 'track.wav'
      assert_sample_rate_on_device 'track.wav', 44_100
    end

    test 'converts wav at 48000hz to 44100hz with bpm appended to filename' do
      source_file('track.wav', fixture: '48000_16.wav', bpm: 128)
      sync
      assert_file_on_device 'track 128 bpm.wav'
      assert_sample_rate_on_device 'track 128 bpm.wav', 44_100
    end

    test 'converts wav at 48000hz to 44100hz, rescaling cue point sample offsets' do
      cue_points = [{ identifier: 1, sample_offset: 48_000, label: 'Drop' }]
      source_file('track.wav', fixture: '48000_16.wav', cue_points: cue_points)
      sync
      rescaled_offset = (48_000 * 44_100 / 48_000.0).round
      assert_cue_points_on_device 'track.wav', [{ identifier: 1, sample_offset: rescaled_offset, label: 'Drop' }]
    end

    test 'converts mp3 to wav' do
      source_file('track.mp3', fixture: '44100.mp3')
      sync
      assert_file_on_device 'track.wav'
      assert_file_not_on_device 'track.mp3'
    end

    test 'converts mp3 to wav with bpm appended to filename' do
      source_file('track.mp3', fixture: '44100.mp3', bpm: 130)
      sync
      assert_file_on_device 'track 130 bpm.wav'
    end

    test 'converts m4a to wav' do
      source_file('track.m4a', fixture: '44100.m4a')
      sync
      assert_file_on_device 'track.wav'
      assert_file_not_on_device 'track.m4a'
    end

    test 'converts m4a to wav with bpm appended to filename' do
      source_file('track.m4a', fixture: '44100.m4a', bpm: 95)
      sync
      assert_file_on_device 'track 95 bpm.wav'
    end

    test 'pads track to 64-bar boundary when bpm is present' do
      source_file('click.wav', fixture: 'click_120bpm_2_5bars.wav')
      sync(pad: true)
      seconds_per_bar = 4 * 60.0 / 120
      expected_duration = 64 * seconds_per_bar
      assert_file_on_device 'click 120 bpm.wav'
      assert_duration_on_device 'click 120 bpm.wav', expected_duration, tolerance: 0.5
    end

    test 'does not pad track when bpm is absent' do
      source_file('track.wav', fixture: '44100_16.wav')
      sync(pad: true)
      assert_file_on_device 'track.wav'
      assert_duration_on_device 'track.wav', 1.0, tolerance: 0.2
    end

    test 'replaces stale bpm filename on device when source bpm changes' do
      source_file('track.wav', fixture: '44100_16.wav', bpm: 120)
      sync
      assert_file_on_device 'track 120 bpm.wav'

      Wavesync::Audio.new(File.join(@source_dir, 'track.wav')).write_bpm(130)
      sync

      assert_file_on_device 'track 130 bpm.wav'
      assert_file_not_on_device 'track 120 bpm.wav'
    end

    test 'writes cue points from device wav to source wav when source has none' do
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Marker' }]
      source_file('track.wav', fixture: '44100_16.wav', cue_points: cue_points)
      sync

      FileUtils.cp(File.join(FIXTURES_PATH, '44100_16.wav'), File.join(@source_dir, 'track.wav'))
      pull_cue_points

      source_cue_points = Wavesync::CueChunk.read(File.join(@source_dir, 'track.wav'))
      assert_equal 1, source_cue_points.size
      assert_equal 44_100, source_cue_points[0][:sample_offset]
      assert_equal 'Marker', source_cue_points[0][:label]
    end
  end
end
