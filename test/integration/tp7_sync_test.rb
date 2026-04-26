# frozen_string_literal: true

require_relative 'integration_test_case'

module Wavesync
  class Tp7SyncTest < IntegrationTestCase
    def self.device_model = 'TP-7'

    test 'copies wav without bpm, no acid bpm on device' do
      source_file('track.wav', fixture: '44100_16.wav')
      sync
      assert_file_on_device 'track.wav'
      assert_no_acid_bpm 'track.wav'
    end

    test 'copies wav with bpm, acid bpm injected on device' do
      source_file('track.wav', fixture: '44100_16.wav', bpm: 120)
      sync
      assert_file_on_device 'track.wav'
      assert_acid_bpm 'track.wav', 120
    end

    test 'copies wav with cue points, cue points preserved on device' do
      cue_points = [
        { identifier: 1, sample_offset: 11_025, label: 'A' },
        { identifier: 2, sample_offset: 22_050, label: 'B' }
      ]
      source_file('track.wav', fixture: '44100_16.wav', cue_points: cue_points)
      sync
      assert_cue_points_on_device 'track.wav', cue_points
    end

    test 'copies wav with bpm and cue points, both preserved on device' do
      cue_points = [{ identifier: 1, sample_offset: 11_025, label: 'Drop' }]
      source_file('track.wav', fixture: '44100_16.wav', bpm: 140, cue_points: cue_points)
      sync
      assert_acid_bpm 'track.wav', 140
      assert_cue_points_on_device 'track.wav', cue_points
    end

    test 'copies mp3 without converting it' do
      source_file('track.mp3', fixture: '44100.mp3')
      sync
      assert_file_on_device 'track.mp3'
    end

    test 'converts m4a to wav' do
      source_file('track.m4a', fixture: '44100.m4a')
      sync
      assert_file_on_device 'track.wav'
      assert_file_not_on_device 'track.m4a'
    end

    test 'converts m4a to wav and injects bpm into acid chunk' do
      source_file('track.m4a', fixture: '44100.m4a', bpm: 140)
      sync
      assert_file_on_device 'track.wav'
      assert_acid_bpm 'track.wav', 140
    end

    test 'converts aif to wav and injects bpm into acid chunk' do
      source_file('track.aif', fixture: '44100_16.aif', bpm: 100)
      sync
      assert_file_on_device 'track.wav'
      assert_acid_bpm 'track.wav', 100
    end

    test 'skips wav on second sync when file already exists on device' do
      source_file('track.wav', fixture: '44100_16.wav', bpm: 120)
      sync
      assert_acid_bpm 'track.wav', 120

      Wavesync::Audio.new(File.join(@source_dir, 'track.wav')).write_bpm(130)
      sync

      assert_acid_bpm 'track.wav', 120
    end

    test 'writes cue points from device wav to source wav when source has none' do
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Marker' }]
      source_file('track.wav', fixture: '44100_16.wav', cue_points: cue_points)
      sync

      FileUtils.cp(File.join(FIXTURES_PATH, '44100_16.wav'), File.join(@source_dir, 'track.wav'))
      sync(pull_cue_points: true)

      source_cue_points = Wavesync::CueChunk.read(File.join(@source_dir, 'track.wav'))
      assert_equal 1, source_cue_points.size
      assert_equal 44_100, source_cue_points[0][:sample_offset]
      assert_equal 'Marker', source_cue_points[0][:label]
    end
  end
end
