# frozen_string_literal: true

require 'tempfile'
require 'fileutils'
require_relative 'test_case'
require_relative '../../lib/wavesync/cue_chunk'

module Wavesync
  class CueChunkTest < Wavesync::TestCase
    test 'read returns empty array for wav without cue chunk' do
      assert_equal [], CueChunk.read(fixture('44100_16.wav'))
    end

    test 'write then read round-trips a single cue point' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil }]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 1, result.size
        assert_equal 1, result[0][:identifier]
        assert_equal 44_100, result[0][:sample_offset]
        assert_nil result[0][:label]
      end
    end

    test 'write then read round-trips multiple cue points' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [
          { identifier: 1, sample_offset: 44_100, label: nil },
          { identifier: 2, sample_offset: 88_200, label: nil },
          { identifier: 3, sample_offset: 132_300, label: nil }
        ]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 3, result.size
        assert_equal([44_100, 88_200, 132_300], result.map { |cp| cp[:sample_offset] })
      end
    end

    test 'write then read round-trips cue point with label' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Verse' }]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 'Verse', result[0][:label]
      end
    end

    test 'write then read round-trips multiple cue points with labels' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [
          { identifier: 1, sample_offset: 44_100, label: 'Verse' },
          { identifier: 2, sample_offset: 88_200, label: 'Chorus' }
        ]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 'Verse', result[0][:label]
        assert_equal 'Chorus', result[1][:label]
      end
    end

    test 'write replaces existing cue chunk' do
      with_temp_copy('44100_16.wav') do |path|
        original_cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil }]
        CueChunk.write(path, "#{path}.v1", original_cue_points)

        updated_cue_points = [{ identifier: 1, sample_offset: 22_050, label: nil }]
        CueChunk.write("#{path}.v1", "#{path}.v2", updated_cue_points)

        result = CueChunk.read("#{path}.v2")
        assert_equal 1, result.size
        assert_equal 22_050, result[0][:sample_offset]
      end
    end

    test 'write with empty array removes existing cue chunk' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil }]
        CueChunk.write(path, "#{path}.with_cues", cue_points)

        CueChunk.write("#{path}.with_cues", "#{path}.no_cues", [])
        assert_equal [], CueChunk.read("#{path}.no_cues")
      end
    end

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end

    def with_temp_copy(name)
      tmp = Tempfile.new(['cue_chunk_test', '.wav'])
      FileUtils.cp(fixture(name), tmp.path)
      yield tmp.path
    ensure
      Dir.glob("#{tmp.path}*").each { |f| File.delete(f) }
      tmp&.close
      tmp&.unlink
    end
  end
end
