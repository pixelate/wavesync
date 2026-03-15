# frozen_string_literal: true

require 'optparse'

module Wavesync
  module Commands
    class Analyze < Command
      FORCE_OPTION = Option.new(short: '-f', long: '--force', description: 'Overwrite existing BPM values')

      self.name = 'analyze'
      self.description = 'Detect and write BPM metadata to library tracks'
      self.options = [FORCE_OPTION].freeze

      def run
        options, config = parse_options(banner: 'Usage: wavesync analyze [options]') do |opts, opts_hash|
          opts.on(*FORCE_OPTION.to_a) { opts_hash[:overwrite] = true }
        end

        Wavesync::Analyzer.new(config.library).analyze(overwrite: options[:overwrite] || false)
      end
    end
  end
end
