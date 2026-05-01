# frozen_string_literal: true
# rbs_inline: enabled

require 'optparse'
require_relative '../transport'

module Wavesync
  module Commands
    class Pull < Command
      DEVICE_OPTION = Option.new(short: '-d', long: '--device NAME', description: 'Name of device to pull from (as defined in config)')

      self.name = 'pull'
      self.description = 'Read cue points from device files and write them back into the source library'
      self.options = [DEVICE_OPTION].freeze

      #: () -> void
      def run
        options, config = parse_options(banner: 'Usage: wavesync pull [options]') do |opts, opts_hash|
          opts.on(*DEVICE_OPTION.to_a) { |value| opts_hash[:device] = value }
        end

        device_pairs = Commands.resolve_device_pairs(config, device_name: options[:device])
        scanner = Wavesync::Scanner.new(config.library)
        ui = Wavesync::UI.new

        device_pairs.each do |pair|
          device_config = pair[0] #: { name: String, model: String, path: String, transport: String, mp3_bitrate: Integer }
          device = pair[1] #: Wavesync::Device
          transport = Wavesync::Transport.for(device_config)
          Commands.with_mtp_retry(transport, device_config[:name]) do
            next unless transport.is_a?(Wavesync::Transport::Mtp)

            transport.prepare! do |index, total, relative_path|
              ui.pull_staging_progress(index, total, device)
              ui.file_progress(relative_path)
            end
          end
          scanner.pull_cue_points(transport.working_directory, device)
        end
      end
    end
  end
end
