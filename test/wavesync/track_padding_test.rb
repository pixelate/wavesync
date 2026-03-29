# frozen_string_literal: true

require_relative 'test_case'
require_relative '../../lib/wavesync/track_padding'

module Wavesync
  class TrackPaddingTest < Wavesync::TestCase
    # At 120 bpm, 1 bar = 4 * 60/120 = 2 seconds.
    # 64 bars = 128 seconds. 128 bars = 256 seconds.

    test 'returns 0 when bpm is nil' do
      assert_equal 0, TrackPadding.compute(60, nil, 64)
    end

    test 'returns 0 when bpm is zero' do
      assert_equal 0, TrackPadding.compute(60, 0, 64)
    end

    test 'returns 0 when duration is nil' do
      assert_equal 0, TrackPadding.compute(nil, 120, 64)
    end

    test 'returns 0 when duration is zero' do
      assert_equal 0, TrackPadding.compute(0, 120, 64)
    end

    test 'returns 0 when track already aligns to bar_multiple bars' do
      # 120 bpm: 1 bar = 2s, 64 bars = 128s — no padding needed
      assert_equal 0, TrackPadding.compute(128, 120, 64)
    end

    test 'pads a short track up to 64 bars' do
      # 120 bpm: 1 bar = 2s, 64 bars = 128s
      # 10s track → target 128s → padding = 118s
      assert_in_delta 118.0, TrackPadding.compute(10, 120, 64), 0.001
    end

    test 'pads a track that exceeds 64 bars up to 128 bars' do
      # 120 bpm: 1 bar = 2s, 64 bars = 128s, 128 bars = 256s
      # 130s track → next power-of-2 multiple of 64 bars is 128 bars = 256s → padding = 126s
      assert_in_delta 126.0, TrackPadding.compute(130, 120, 64), 0.001
    end

    test 'pads a 192-bar track to 256 bars, not 192' do
      assert_in_delta 128.0, TrackPadding.compute(384, 120, 64), 0.001
    end

    test 'pads a track just over 128 bars to 256 bars' do
      assert_in_delta 254.0, TrackPadding.compute(258, 120, 64), 0.001
    end

    test 'returns 0 when track aligns to 128 bars exactly' do
      # 120 bpm: 128 bars = 256s
      assert_equal 0, TrackPadding.compute(256, 120, 64)
    end

    test 'works with non-round bpm' do
      # 140 bpm: 1 bar = 4 * 60/140 = 12/7 s ≈ 1.714286s, 64 bars ≈ 109.714s
      bpm = 140
      seconds_per_bar = 4 * 60.0 / bpm
      target_bars = 64
      target_duration = target_bars * seconds_per_bar
      duration = 10.0
      expected_padding = target_duration - duration
      assert_in_delta expected_padding, TrackPadding.compute(duration, bpm, 64), 0.001
    end

    test 'handles string bpm' do
      # Same as numeric bpm test
      assert_in_delta 118.0, TrackPadding.compute(10, '120', 64), 0.001
    end
  end
end
