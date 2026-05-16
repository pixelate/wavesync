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

    test 'append_to_file adds cue points to file without existing cue chunk' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil }]
        CueChunk.append_to_file(path, cue_points)
        result = CueChunk.read(path)
        assert_equal 1, result.size
        assert_equal 44_100, result[0][:sample_offset]
      end
    end

    test 'append_to_file adds multiple cue points with labels' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [
          { identifier: 1, sample_offset: 44_100, label: 'Verse' },
          { identifier: 2, sample_offset: 88_200, label: 'Chorus' }
        ]
        CueChunk.append_to_file(path, cue_points)
        result = CueChunk.read(path)
        assert_equal 2, result.size
        assert_equal 'Verse', result[0][:label]
        assert_equal 'Chorus', result[1][:label]
      end
    end

    test 'append_to_file does nothing when given empty array' do
      with_temp_copy('44100_16.wav') do |path|
        original_size = File.size(path)
        CueChunk.append_to_file(path, [])
        assert_equal original_size, File.size(path)
      end
    end

    test 'read returns note field as nil when no note sub-chunks present' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Verse', note: nil }]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_nil result[0][:note]
      end
    end

    test 'write then read round-trips cue point with note' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil, note: 'start' }]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 1, result.size
        assert_equal 'start', result[0][:note]
        assert_nil result[0][:label]
      end
    end

    test 'write then read round-trips TP-7 loop with start and end notes' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [
          { identifier: 1, sample_offset: 44_100, label: nil, note: 'start' },
          { identifier: 2, sample_offset: 88_200, label: nil, note: 'end' }
        ]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 2, result.size
        assert_equal 'start', result[0][:note]
        assert_equal 'end', result[1][:note]
      end
    end

    test 'write then read round-trips cue point with both label and note' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Loop A', note: 'start' }]
        CueChunk.write(path, "#{path}.out", cue_points)
        result = CueChunk.read("#{path}.out")
        assert_equal 'Loop A', result[0][:label]
        assert_equal 'start', result[0][:note]
      end
    end

    test 'append_to_file writes note sub-chunks' do
      with_temp_copy('44100_16.wav') do |path|
        cue_points = [
          { identifier: 1, sample_offset: 44_100, label: nil, note: 'start' },
          { identifier: 2, sample_offset: 88_200, label: nil, note: 'end' }
        ]
        CueChunk.append_to_file(path, cue_points)
        result = CueChunk.read(path)
        assert_equal 'start', result[0][:note]
        assert_equal 'end', result[1][:note]
      end
    end

    test 'same? treats different notes as different' do
      cue_points_a = [{ identifier: 1, sample_offset: 44_100, label: nil, note: 'start' }]
      cue_points_b = [{ identifier: 1, sample_offset: 44_100, label: nil, note: nil }]
      refute CueChunk.same?(cue_points_a, cue_points_b)
    end

    test 'loops pairs cue points with start and end notes' do
      cue_points = [
        { identifier: 1, sample_offset: 44_100, label: nil, note: 'start' },
        { identifier: 2, sample_offset: 88_200, label: nil, note: 'end' }
      ]
      result = CueChunk.loops(cue_points)
      assert_equal 1, result.size
      assert_equal 44_100, result[0][:start_sample]
      assert_equal 88_200, result[0][:end_sample]
    end

    test 'loops returns empty array when no start/end notes present' do
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: 'Verse', note: nil }]
      assert_equal [], CueChunk.loops(cue_points)
    end

    test 'loops ignores unpaired start without matching end' do
      cue_points = [{ identifier: 1, sample_offset: 44_100, label: nil, note: 'start' }]
      assert_equal [], CueChunk.loops(cue_points)
    end

    test 'loops pairs multiple loops in order of sample offset' do
      cue_points = [
        { identifier: 1, sample_offset: 10_000, label: nil, note: 'start' },
        { identifier: 2, sample_offset: 20_000, label: nil, note: 'end' },
        { identifier: 3, sample_offset: 30_000, label: nil, note: 'start' },
        { identifier: 4, sample_offset: 40_000, label: nil, note: 'end' }
      ]
      result = CueChunk.loops(cue_points)
      assert_equal 2, result.size
      assert_equal({ start_sample: 10_000, end_sample: 20_000 }, result[0])
      assert_equal({ start_sample: 30_000, end_sample: 40_000 }, result[1])
    end

    test 'loops rejects ranges where end is not after start' do
      cue_points = [
        { identifier: 1, sample_offset: 44_100, label: nil, note: 'start' },
        { identifier: 2, sample_offset: 22_050, label: nil, note: 'end' }
      ]
      assert_equal [], CueChunk.loops(cue_points)
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
