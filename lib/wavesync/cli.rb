# frozen_string_literal: true

require 'optparse'

module Wavesync
  class CLI
    def self.start
      command = ARGV.first && !ARGV.first.start_with?('-') ? ARGV.shift : 'sync'

      case command
      when 'sync'
        start_sync
      when 'analyze'
        start_analyze
      when 'set'
        start_set
      else
        puts "Unknown command: #{command}"
        puts 'Available commands: sync, analyze, set'
        exit 1
      end
    end

    def self.start_sync
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: wavesync sync [options]'

        opts.on('-d', '--device NAME', 'Name of device to sync (as defined in config)') do |value|
          options[:device] = value
        end

        opts.on('-c', '--config PATH', 'Path to wavesync config YAML file') do |value|
          options[:config] = value
        end
      end

      parser.parse!

      config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
      config = Wavesync::Config.load(config_path)

      device_configs = config.device_configs
      if options[:device]
        device_configs = device_configs.select { |device_config| device_config[:name] == options[:device] }
        if device_configs.empty?
          known = config.device_configs.map { |device_config| device_config[:name] }.join(', ')
          puts "Unknown device \"#{options[:device]}\". Devices in config: #{known}"
          exit 1
        end
      end

      device_configs.each do |device_config|
        next if Wavesync::Device.find_by(name: device_config[:model])

        supported = Wavesync::Device.all.map(&:name).join(', ')
        puts "Unknown device model \"#{device_config[:model]}\" in config. Supported models: #{supported}"
        exit 1
      end

      scanner = Wavesync::Scanner.new(config.library)

      device_configs.each do |device_config|
        scanner.sync(device_config[:path], Wavesync::Device.find_by(name: device_config[:model]))
      end
    end

    def self.start_set
      subcommand = ARGV.shift

      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: wavesync set <subcommand> [options]'

        opts.on('-c', '--config PATH', 'Path to wavesync config YAML file') do |value|
          options[:config] = value
        end
      end

      parser.parse!

      config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
      config = Wavesync::Config.load(config_path)

      case subcommand
      when 'create'
        name = require_set_name('create')
        if Wavesync::Set.exists?(config.library, name)
          puts "Set '#{name}' already exists. Use 'wavesync set edit #{name}' to edit it."
          exit 1
        end
        set = Wavesync::Set.new(config.library, name)
        Wavesync::SetEditor.new(set, config.library).run
      when 'edit'
        name = require_set_name('edit')
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
          sets.each { |s| puts "#{s.name} (#{s.tracks.size} tracks)" }
        end
      else
        puts "Unknown subcommand: #{subcommand || '(none)'}"
        puts 'Available subcommands: create, edit, list'
        exit 1
      end
    end

    def self.require_set_name(subcommand)
      name = ARGV.shift
      unless name
        puts "Usage: wavesync set #{subcommand} <name>"
        exit 1
      end
      name
    end

    def self.start_analyze
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = 'Usage: wavesync analyze [options]'

        opts.on('-c', '--config PATH', 'Path to wavesync config YAML file') do |value|
          options[:config] = value
        end

        opts.on('-f', '--force', 'Overwrite existing BPM values') do
          options[:overwrite] = true
        end
      end

      parser.parse!

      config_path = options[:config] || Wavesync::Config::DEFAULT_PATH
      config = Wavesync::Config.load(config_path)

      Wavesync::Analyzer.new(config.library).analyze(overwrite: options[:overwrite] || false)
    end
  end
end
