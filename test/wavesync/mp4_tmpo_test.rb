# frozen_string_literal: true

require 'tempfile'
require 'fileutils'
require_relative 'test_case'
require_relative '../../lib/wavesync/mp4_tmpo'

module Wavesync
  class Mp4TmpoTest < Wavesync::TestCase
    test 'read_bpm returns nil for m4a without a tmpo atom' do
      assert_nil Mp4Tmpo.read_bpm(fixture('44100.m4a'))
    end

    test 'write then read round-trips bpm' do
      with_temp_copy('44100.m4a') do |path|
        Mp4Tmpo.write_bpm(path, 128)
        assert_equal 128, Mp4Tmpo.read_bpm(path)
      end
    end

    test 'write replaces an existing tmpo atom rather than duplicating it' do
      with_temp_copy('44100.m4a') do |path|
        Mp4Tmpo.write_bpm(path, 120)
        Mp4Tmpo.write_bpm(path, 90)
        assert_equal 90, Mp4Tmpo.read_bpm(path)
      end
    end

    test 'write keeps the file decodable' do
      with_temp_copy('44100.m4a') do |path|
        Mp4Tmpo.write_bpm(path, 174)
        assert system("ffmpeg -v error -i #{path.inspect} -f null - >/dev/null 2>&1"),
               'ffmpeg failed to decode the file after writing tmpo'
      end
    end

    test 'write preserves existing string tags' do
      with_temp_copy('44100.m4a') do |path|
        before = probe_tags(path)
        Mp4Tmpo.write_bpm(path, 100)
        assert_equal before, probe_tags(path)
      end
    end

    private

    def fixture(name)
      File.join(FIXTURES_PATH, name)
    end

    def with_temp_copy(name)
      tmp = Tempfile.new(['mp4_tmpo_test', File.extname(name)])
      FileUtils.cp(fixture(name), tmp.path)
      yield tmp.path
    ensure
      Dir.glob("#{tmp.path}*").each { |f| File.delete(f) }
      tmp&.close
      tmp&.unlink
    end

    def probe_tags(path)
      `ffprobe -v quiet -show_entries format_tags -of default=noprint_wrappers=1 #{path.inspect}`.strip
    end
  end
end
