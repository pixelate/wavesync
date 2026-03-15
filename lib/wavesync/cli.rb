# frozen_string_literal: true

require_relative 'commands'

module Wavesync
  class CLI
    def self.start
      command_name = ARGV.first && !ARGV.first.start_with?('-') ? ARGV.shift : 'sync'
      command_class = Commands::ALL.find { |cmd| command_name == cmd.name }

      if command_class
        command_class.new.run
      else
        puts "Unknown command: #{command_name}"
        puts "Available commands: #{Commands::ALL.map(&:name).join(', ')}"
        exit 1
      end
    end
  end
end
