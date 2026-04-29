# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Transport
    SUPPORTED_KINDS = %w[filesystem mtp].freeze

    #: ({ name: String, model: String, path: String, transport: String? } device_config) -> (Filesystem | Mtp)
    def self.for(device_config)
      kind = device_config[:transport] || 'filesystem'
      case kind
      when 'filesystem' then Filesystem.new(device_config)
      when 'mtp' then Mtp.new(device_config)
      else raise ArgumentError, "Unsupported transport: #{kind.inspect}. Supported: #{SUPPORTED_KINDS.join(', ')}"
      end
    end
  end
end

require_relative 'transport/filesystem'
require_relative 'transport/mtp'
