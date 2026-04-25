# frozen_string_literal: true
# rbs_inline: enabled

require 'open3'
require_relative 'ffmpeg/probe'

module Wavesync
  class FFMPEG
    class Error < StandardError; end

    #: () -> String
    def self.binary
      @binary ||= locate_binary('ffmpeg')
    end

    #: () -> String
    def self.ffplay_binary
      @ffplay_binary ||= binary.sub('ffmpeg', 'ffplay')
    end

    #: () -> void
    def initialize
      @inputs = [] #: Array[Hash[Symbol, String?]]
      @options = {} #: Hash[Symbol, untyped]
      @metadata_pairs = [] #: Array[[String, String]]
    end

    #: (String source, ?format: String?) -> self
    def input(source, format: nil)
      @inputs << { source: source, format: format }
      self
    end

    #: (String codec) -> self
    def audio_codec(codec)
      @options[:audio_codec] = codec
      self
    end

    #: (Integer rate) -> self
    def sample_rate(rate)
      @options[:sample_rate] = rate
      self
    end

    #: (String bitrate) -> self
    def audio_bitrate(bitrate)
      @options[:audio_bitrate] = bitrate
      self
    end

    #: (String filter) -> self
    def audio_filter(filter)
      @options[:audio_filter] = filter
      self
    end

    #: (String graph) -> self
    def filter_complex(graph)
      @options[:filter_complex] = graph
      self
    end

    #: (String format) -> self
    def output_format(format)
      @options[:output_format] = format
      self
    end

    #: (Numeric seconds) -> self
    def duration(seconds)
      @options[:duration] = seconds
      self
    end

    #: () -> self
    def copy_streams
      @options[:copy_streams] = true
      self
    end

    #: (Integer source_index) -> self
    def map_metadata(source_index)
      @options[:map_metadata] = source_index
      self
    end

    #: (String key, String value) -> self
    def metadata(key, value)
      @metadata_pairs << [key, value]
      self
    end

    #: (String flags) -> self
    def movflags(flags)
      @options[:movflags] = flags
      self
    end

    #: (Integer version) -> self
    def write_id3v2(version)
      @options[:write_id3v2] = version
      self
    end

    #: (String output_path) -> void
    def run(output_path)
      args = ['-y']

      @inputs.each do |input|
        args += ['-f', input[:format]] if input[:format]
        args += ['-i', input[:source]]
      end

      args += ['-loglevel', 'warning', '-nostats', '-hide_banner']
      args += ['-c', 'copy'] if @options[:copy_streams]
      args += ['-map_metadata', @options[:map_metadata].to_s] if @options.key?(:map_metadata)
      @metadata_pairs.each { |key, value| args += ['-metadata', "#{key}=#{value}"] }
      args += ['-filter_complex', @options[:filter_complex]] if @options[:filter_complex]
      args += ['-af', @options[:audio_filter]] if @options[:audio_filter]
      args += ['-acodec', @options[:audio_codec]] if @options[:audio_codec]
      args += ['-b:a', @options[:audio_bitrate]] if @options[:audio_bitrate]
      args += ['-ar', @options[:sample_rate].to_s] if @options[:sample_rate]
      args += ['-t', @options[:duration].to_s] if @options[:duration]
      args += ['-movflags', @options[:movflags]] if @options[:movflags]
      args += ['-write_id3v2', @options[:write_id3v2].to_s] if @options[:write_id3v2]
      args += ['-f', @options[:output_format]] if @options[:output_format]
      args << output_path

      _stdout, stderr, status = Open3.capture3(self.class.binary, *args)
      raise Error, "ffmpeg failed: #{stderr}" unless status.success?
    end

    private

    #: (String binary_name) -> String
    def self.locate_binary(binary_name)
      stdout, _stderr, _status = Open3.capture3('which', binary_name)
      path = stdout.strip
      path.empty? ? binary_name : path
    end
    private_class_method :locate_binary
  end
end
