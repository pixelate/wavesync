# frozen_string_literal: true

require 'optparse'
require 'rainbow'

module Wavesync
  module Commands
    class Help < Command
      self.name = 'help'
      self.description = 'Show this help message'

      DESCRIPTION_COLUMN = 23

      def run
        subcommand_name = ARGV.shift

        if subcommand_name
          command = ALL.find { |cmd| subcommand_name == cmd.name }
          if command
            show_command_help(command)
          else
            puts "Unknown command: #{subcommand_name}"
            puts "Available commands: #{ALL.map(&:name).reject { |cmd_name| cmd_name == self.class.name }.join(', ')}"
            exit 1
          end
        else
          show_general_help
        end
      end

      private

      def show_general_help
        puts 'Usage: wavesync [command] [options]'
        puts ''
        puts 'Commands:'
        ALL.each do |command|
          if command.subcommands.any?
            command.subcommands.each { |subcommand| puts format_command_line(subcommand.usage, subcommand.description) }
          else
            puts format_command_line(command.name, command.description)
            command.options.each { |option| puts format_option_line(option, indent: 4) }
          end
          puts ''
        end
        puts 'Options:'
        GLOBAL_OPTIONS.each { |option| puts format_option_line(option, indent: 2) }
      end

      def show_command_help(command)
        if command.subcommands.any?
          puts "Usage: wavesync #{command.name} <subcommand> [options]"
          puts ''
          puts 'Subcommands:'
          command.subcommands.each do |subcommand|
            subcommand_key = subcommand.usage.delete_prefix("#{command.name} ")
            puts "  #{subcommand_key.ljust(DESCRIPTION_COLUMN - 2)}#{subcommand.description}"
          end
          puts ''
          puts 'Options:'
          GLOBAL_OPTIONS.each { |option| puts "  #{option.short}, #{option.long}  #{option.description}" }
        else
          OptionParser.new do |opts|
            opts.banner = "Usage: wavesync #{command.name} [options]"
            (command.options + GLOBAL_OPTIONS).each { |option| opts.on(*option.to_a) }
            puts opts
          end
        end
      end

      def format_command_line(name, description)
        "  #{name.ljust(DESCRIPTION_COLUMN - 2)}#{description}"
      end

      def format_option_line(option, indent:)
        key = "#{option.short}, #{option.long}"
        Rainbow("#{' ' * indent}#{key.ljust(DESCRIPTION_COLUMN - indent)}#{option.description}").darkgray
      end
    end
  end
end
