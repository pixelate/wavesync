# frozen_string_literal: true
# rbs_inline: enabled

require 'optparse'
require_relative '../transport'

module Wavesync
  module Commands
    class Sync < Command
      DEVICE_OPTION = Option.new(short: '-d', long: '--device NAME', description: 'Name of device to sync (as defined in config)')
      PAD_OPTION = Option.new(short: '-p', long: '--pad', description: 'Pad tracks with silence so total length is a multiple of 64 bars (Octatrack only)')

      self.name = 'sync'
      self.description = 'Sync music library to a device'
      self.options = [DEVICE_OPTION, PAD_OPTION].freeze

      #: () -> void
      def run
        options, config = parse_options(banner: 'Usage: wavesync sync [options]') do |opts, opts_hash|
          opts.on(*DEVICE_OPTION.to_a) { |value| opts_hash[:device] = value }
          opts.on(*PAD_OPTION.to_a) { opts_hash[:pad] = true }
        end

        device_pairs = Commands.resolve_device_pairs(config, device_name: options[:device])
        scanner = Wavesync::Scanner.new(config.library)

        device_pairs.each do |pair|
          device_config = pair[0] #: { name: String, model: String, path: String, transport: String, mp3_bitrate: Integer }
          device = pair[1] #: Wavesync::Device
          transport = Wavesync::Transport.for(device_config)
          Commands.with_mtp_retry(transport, device_config[:name]) do
            puts "Pushing to #{device_config[:name]} via MTP..." if transport.is_a?(Wavesync::Transport::Mtp)
            transport.begin_push!
          end
          begin
            scanner.sync(transport.working_directory, device, pad: options[:pad] || false, staged: transport.is_a?(Wavesync::Transport::Mtp), mp3_bitrate: device_config[:mp3_bitrate]) do |relative_path|
              transport.push_file!(relative_path)
            end
          ensure
            transport.finish_push!
          end
        end
      end
    end
  end
end
