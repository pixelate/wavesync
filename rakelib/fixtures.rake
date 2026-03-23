# frozen_string_literal: true

FIXTURES_PATH = 'test/fixtures'
FREQUENCY = 440
DURATION = 1
AMPLITUDE = 0.5
SAMPLE_RATES = [22_050, 44_100, 48_000, 88_200, 96_000].freeze
MP3_SAMPLE_RATES = [22_050, 44_100, 48_000].freeze
BIT_DEPTHS = [8, 16, 24].freeze
WAV_CODECS = { 8 => 'pcm_u8', 16 => 'pcm_s16le', 24 => 'pcm_s24le' }.freeze
AIFF_CODECS = { 8 => 'pcm_s8', 16 => 'pcm_s16be', 24 => 'pcm_s24be' }.freeze

namespace :fixtures do
  desc 'Regenerate all test audio fixtures'
  task :generate do
    SAMPLE_RATES.each do |sample_rate|
      BIT_DEPTHS.each do |bit_depth|
        sh 'ffmpeg', '-y',
           '-f', 'lavfi',
           '-i', "sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}",
           '-af', "volume=#{AMPLITUDE}",
           '-acodec', WAV_CODECS[bit_depth],
           "#{FIXTURES_PATH}/#{sample_rate}_#{bit_depth}.wav"
      end

      sh 'ffmpeg', '-y',
         '-f', 'lavfi',
         '-i', "sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}",
         '-af', "volume=#{AMPLITUDE}",
         "#{FIXTURES_PATH}/#{sample_rate}.m4a"

      next unless MP3_SAMPLE_RATES.include?(sample_rate)

      sh 'ffmpeg', '-y',
         '-f', 'lavfi',
         '-i', "sine=frequency=#{FREQUENCY}:sample_rate=#{sample_rate}:duration=#{DURATION}",
         '-af', "volume=#{AMPLITUDE}",
         "#{FIXTURES_PATH}/#{sample_rate}.mp3"
    end

    BIT_DEPTHS.each do |bit_depth|
      %w[aif aiff].each do |ext|
        sh 'ffmpeg', '-y',
           '-f', 'lavfi',
           '-i', "sine=frequency=#{FREQUENCY}:sample_rate=44100:duration=#{DURATION}",
           '-af', "volume=#{AMPLITUDE}",
           '-acodec', AIFF_CODECS[bit_depth],
           '-f', 'aiff',
           "#{FIXTURES_PATH}/44100_#{bit_depth}.#{ext}"
      end
    end
  end
end
