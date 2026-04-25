# frozen_string_literal: true
# rbs_inline: enabled

require 'optparse'

module Wavesync
  module Commands
    class Set < Command
      self.name = 'set'
      self.subcommands = [
        Subcommand.new(usage: 'set create NAME', description: 'Create a new track set'),
        Subcommand.new(usage: 'set edit NAME', description: 'Edit an existing track set'),
        Subcommand.new(usage: 'set list', description: 'List all track sets')
      ].freeze

      #: () -> void
      def run
        subcommand = ARGV.shift

        _options, config = parse_options(banner: 'Usage: wavesync set <subcommand> [options]')

        case subcommand
        when 'create'
          name = require_name('create')
          if Wavesync::Set.exists?(config.library, name)
            puts "Set '#{name}' already exists. Use 'wavesync set edit #{name}' to edit it."
            exit 1
          end
          set = Wavesync::Set.new(config.library, name)
          Wavesync::SetEditor.new(set, config.library).run
        when 'edit'
          name = require_name('edit')
          unless Wavesync::Set.exists?(config.library, name)
            puts "Set '#{name}' not found. Use 'wavesync set create #{name}' to create it."
            exit 1
          end
          set = Wavesync::Set.load(config.library, name)
          Wavesync::SetEditor.new(set, config.library).run
        when 'list'
          sets = Wavesync::Set.all(config.library)
          if sets.empty?
            puts 'No sets found.'
          else
            sets.each { |set| puts "#{set.name} (#{set.tracks.size} tracks)" }
          end
        else
          puts "Unknown subcommand: #{subcommand || '(none)'}"
          puts 'Available subcommands: create, edit, list'
          exit 1
        end
      end

      private

      #: (String subcommand) -> String
      def require_name(subcommand)
        name = ARGV.shift
        unless name
          puts "Usage: wavesync set #{subcommand} <name>"
          exit 1
        end
        name
      end
    end
  end
end
