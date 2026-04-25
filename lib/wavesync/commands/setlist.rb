# frozen_string_literal: true
# rbs_inline: enabled

require 'optparse'

module Wavesync
  module Commands
    class Setlist < Command
      self.name = 'setlist'
      self.subcommands = [
        Subcommand.new(usage: 'setlist create NAME', description: 'Create a new setlist'),
        Subcommand.new(usage: 'setlist edit NAME', description: 'Edit an existing setlist'),
        Subcommand.new(usage: 'setlist list', description: 'List all setlists')
      ].freeze

      #: () -> void
      def run
        subcommand = ARGV.shift

        _options, config = parse_options(banner: 'Usage: wavesync setlist <subcommand> [options]')

        case subcommand
        when 'create'
          name = require_name('create')
          if Wavesync::Setlist.exists?(config.library, name)
            puts "Setlist '#{name}' already exists. Use 'wavesync setlist edit #{name}' to edit it."
            exit 1
          end
          setlist = Wavesync::Setlist.new(config.library, name)
          Wavesync::SetlistEditor.new(setlist, config.library).run
        when 'edit'
          name = require_name('edit')
          unless Wavesync::Setlist.exists?(config.library, name)
            puts "Setlist '#{name}' not found. Use 'wavesync setlist create #{name}' to create it."
            exit 1
          end
          setlist = Wavesync::Setlist.load(config.library, name)
          Wavesync::SetlistEditor.new(setlist, config.library).run
        when 'list'
          setlists = Wavesync::Setlist.all(config.library)
          if setlists.empty?
            puts 'No setlists found.'
          else
            setlists.each { |setlist| puts "#{setlist.name} (#{setlist.tracks.size} tracks)" }
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
          puts "Usage: wavesync setlist #{subcommand} <name>"
          exit 1
        end
        name
      end
    end
  end
end
