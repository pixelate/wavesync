# frozen_string_literal: true

require 'tempfile'
require 'fileutils'
require_relative 'test_case'
require_relative '../../lib/wavesync/acid_chunk'

module Wavesync
  class AcidChunkTest < Wavesync::TestCase
    test 'read_bpm returns nil for wav without acid chunk' do
      assert_nil AcidChunk.read_bpm(fixture('44100_16.wav'))
    end

    test 'write_bpm then read_bpm round-trips correctly' do
      with_temp_copy('44100_16.wav') do |path|
        AcidChunk.write_bpm(path, "#{path}.out", 128)
        assert_equal 128, AcidChunk.read_bpm("#{path}.out").to_i
      end
    end

    test 'write_bpm overwrites existing bpm when acid chunk already present' do
      with_temp_copy('44100_16.wav') do |path|
        out = "#{path}.out"
        AcidChunk.write_bpm(path, out, 120)
        AcidChunk.write_bpm(out, "#{out}2", 140)
        assert_equal 140, AcidChunk.read_bpm("#{out}2").to_i
      end
    end

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end

    def with_temp_copy(name)
      tmp = Tempfile.new(['acid_chunk_test', '.wav'])
      FileUtils.cp(fixture(name), tmp.path)
      yield tmp.path
    ensure
      Dir.glob("#{tmp.path}*").each { |f| File.delete(f) }
      tmp&.close
      tmp&.unlink
    end
  end
end
