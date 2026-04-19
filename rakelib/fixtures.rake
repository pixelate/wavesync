# frozen_string_literal: true

require_relative '../lib/wavesync/ffmpeg'

FIXTURES_PATH = 'test/fixtures'
FREQUENCY = 440
DURATION = 1
AMPLITUDE = 0.5
SAMPLE_RATES = [22_050, 44_100, 48_000, 88_200, 96_000].freeze
MP3_SAMPLE_RATES = [22_050, 44_100, 48_000].freeze
BIT_DEPTHS = [8, 16, 24].freeze
WAV_CODECS = { 8 => 'pcm_u8', 16 => 'pcm_s16le', 24 => 'pcm_s24le' }.freeze
AIFF_CODECS = { 8 => 'pcm_s8', 16 => 'pcm_s16be', 24 => 'pcm_s24be' }.freeze

CLICK_TRACK_BPM = 120
CLICK_TRACK_SAMPLE_RATE = 44_100
CLICK_TRACK_CLICK_MS = 30
CLICK_TRACK_BEATS_PER_BAR = 4
CLICK_TRACK_DOWNBEAT_FREQ = 880
CLICK_TRACK_BEAT_FREQ = 440

DELAYED_START_BEATS = [2, 3, 4].freeze
DELAYED_CLICK_TRACK_COMPLETE_BARS = 4

# Builds an FFmpeg filter_complex graph that mixes downbeat and beat clicks.
# beat_times_ms: Array of all beat timestamps in milliseconds (index order).
# downbeat_times_ms: Subset of beat_times_ms that fall on beat ONE.
# total_duration_s: Total output duration in seconds (used for apad).
def build_click_track_filter(beat_times_ms:, downbeat_times_ms:, total_duration_s:)
  other_beat_times_ms = beat_times_ms - downbeat_times_ms
  num_downbeats = downbeat_times_ms.size
  num_other_beats = other_beat_times_ms.size
  total_beats = num_downbeats + num_other_beats

  filter_parts = []
  filter_parts << "[0]asplit=#{num_downbeats}#{(0...num_downbeats).map { |i| "[d#{i}]" }.join}"
  filter_parts << "[1]asplit=#{num_other_beats}#{(0...num_other_beats).map { |i| "[b#{i}]" }.join}"

  output_labels = []

  downbeat_times_ms.each_with_index do |time_ms, i|
    label = "od#{i}"
    filter_parts << "[d#{i}]adelay=#{time_ms},apad=whole_dur=#{total_duration_s}[#{label}]"
    output_labels << "[#{label}]"
  end

  other_beat_times_ms.each_with_index do |time_ms, i|
    label = "ob#{i}"
    filter_parts << "[b#{i}]adelay=#{time_ms},apad=whole_dur=#{total_duration_s}[#{label}]"
    output_labels << "[#{label}]"
  end

  filter_parts << "#{output_labels.join}amix=inputs=#{total_beats}:normalize=0,volume=0.5"
  filter_parts.join(';')
end

namespace :fixtures do
  desc 'Regenerate all test audio fixtures'
  task :generate do
    SAMPLE_RATES.each do |sample_rate|
      BIT_DEPTHS.each do |bit_depth|
        Wavesync::FFMPEG.new
                        .input("sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}", format: 'lavfi')
                        .audio_filter("volume=#{AMPLITUDE}")
                        .audio_codec(WAV_CODECS[bit_depth])
                        .run("#{FIXTURES_PATH}/#{sample_rate}_#{bit_depth}.wav")
      end

      Wavesync::FFMPEG.new
                      .input("sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}", format: 'lavfi')
                      .audio_filter("volume=#{AMPLITUDE}")
                      .run("#{FIXTURES_PATH}/#{sample_rate}.m4a")

      next unless MP3_SAMPLE_RATES.include?(sample_rate)

      Wavesync::FFMPEG.new
                      .input("sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}", format: 'lavfi')
                      .audio_filter("volume=#{AMPLITUDE}")
                      .run("#{FIXTURES_PATH}/#{sample_rate}.mp3")
    end

    BIT_DEPTHS.each do |bit_depth|
      %w[aif aiff].each do |ext|
        Wavesync::FFMPEG.new
                        .input("sine=frequency=#{FREQUENCY}:sample_rate=44100:duration=#{DURATION}", format: 'lavfi')
                        .audio_filter("volume=#{AMPLITUDE}")
                        .audio_codec(AIFF_CODECS[bit_depth])
                        .output_format('aiff')
                        .run("#{FIXTURES_PATH}/44100_#{bit_depth}.#{ext}")
      end
    end

    Rake::Task['fixtures:generate_click_track'].invoke
    Rake::Task['fixtures:generate_delayed_downbeat_click_tracks'].invoke
  end

  desc 'Generate click track fixture: 120 BPM, 2.5 bars, 44100Hz 16-bit WAV with ACID BPM'
  task :generate_click_track do
    require_relative '../lib/wavesync/acid_chunk'

    click_bpm = CLICK_TRACK_BPM
    click_bars = 2.5
    click_sample_rate = CLICK_TRACK_SAMPLE_RATE
    click_ms = CLICK_TRACK_CLICK_MS
    output_path = "#{FIXTURES_PATH}/click_120bpm_2_5bars.wav"

    beat_duration_ms = (60_000.0 / click_bpm).round
    total_beats = (click_bars * CLICK_TRACK_BEATS_PER_BAR).to_i
    total_duration_s = click_bars * CLICK_TRACK_BEATS_PER_BAR * 60.0 / click_bpm

    beat_times_ms = Array.new(total_beats) { |i| i * beat_duration_ms }
    downbeat_times_ms = beat_times_ms.select.with_index { |_, i| (i % CLICK_TRACK_BEATS_PER_BAR).zero? }

    filter_graph = build_click_track_filter(
      beat_times_ms: beat_times_ms,
      downbeat_times_ms: downbeat_times_ms,
      total_duration_s: total_duration_s
    )

    Wavesync::FFMPEG.new
                    .input("sine=frequency=#{CLICK_TRACK_DOWNBEAT_FREQ}:sample_rate=#{click_sample_rate}:duration=#{click_ms / 1000.0}", format: 'lavfi')
                    .input("sine=frequency=#{CLICK_TRACK_BEAT_FREQ}:sample_rate=#{click_sample_rate}:duration=#{click_ms / 1000.0}", format: 'lavfi')
                    .filter_complex(filter_graph)
                    .audio_codec('pcm_s16le')
                    .sample_rate(click_sample_rate)
                    .duration(total_duration_s)
                    .run(output_path)

    Wavesync::AcidChunk.write_bpm_in_place(output_path, click_bpm)
    puts "Generated #{output_path} (#{click_bpm} BPM, #{click_bars} bars, #{total_duration_s}s)"
  end

  desc 'Generate click track fixtures starting on beats 2, 3, and 4 for beat alignment testing'
  task :generate_delayed_downbeat_click_tracks do
    require_relative '../lib/wavesync/acid_chunk'

    DELAYED_START_BEATS.each do |start_beat|
      bpm = CLICK_TRACK_BPM
      complete_bars = DELAYED_CLICK_TRACK_COMPLETE_BARS
      sample_rate = CLICK_TRACK_SAMPLE_RATE
      click_ms = CLICK_TRACK_CLICK_MS
      beats_per_bar = CLICK_TRACK_BEATS_PER_BAR

      beat_duration_ms = (60_000.0 / bpm).round
      beats_in_pickup = beats_per_bar - start_beat + 1
      total_beats = beats_in_pickup + (complete_bars * beats_per_bar)
      total_duration_s = total_beats * 60.0 / bpm

      beat_times_ms = Array.new(total_beats) { |i| i * beat_duration_ms }
      downbeat_times_ms = beat_times_ms.select.with_index { |_, i| ((start_beat - 1 + i) % beats_per_bar).zero? }

      filter_graph = build_click_track_filter(
        beat_times_ms: beat_times_ms,
        downbeat_times_ms: downbeat_times_ms,
        total_duration_s: total_duration_s
      )

      output_path = "#{FIXTURES_PATH}/click_#{bpm}bpm_#{complete_bars}bars_start_beat#{start_beat}.wav"

      Wavesync::FFMPEG.new
                      .input("sine=frequency=#{CLICK_TRACK_DOWNBEAT_FREQ}:sample_rate=#{sample_rate}:duration=#{click_ms / 1000.0}", format: 'lavfi')
                      .input("sine=frequency=#{CLICK_TRACK_BEAT_FREQ}:sample_rate=#{sample_rate}:duration=#{click_ms / 1000.0}", format: 'lavfi')
                      .filter_complex(filter_graph)
                      .audio_codec('pcm_s16le')
                      .sample_rate(sample_rate)
                      .duration(total_duration_s)
                      .run(output_path)

      Wavesync::AcidChunk.write_bpm_in_place(output_path, bpm)

      first_downbeat_s = beats_in_pickup * 60.0 / bpm
      puts "Generated #{output_path} (#{bpm} BPM, #{complete_bars} complete bars, starts on beat #{start_beat}, first downbeat at #{first_downbeat_s}s)"
    end
  end
end
