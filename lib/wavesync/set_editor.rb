# frozen_string_literal: true

require 'tty-prompt'
require 'io/console'

module Wavesync
  class SetEditor
    KEY_MAP = {
      'a' => :add,
      'u' => :move_up,
      'd' => :move_down,
      'r' => :remove,
      's' => :save,
      'c' => :quit,
      "\e[A" => :cursor_up,
      "\e[B" => :cursor_down
    }.freeze

    def initialize(set, library_path)
      @set = set
      @library_path = library_path
      @prompt = TTY::Prompt.new(interrupt: :exit, active_color: :red)
      @ui = UI.new
      @selected = @set.tracks.empty? ? nil : 0
    end

    def run
      loop do
        render
        action = KEY_MAP[read_key]
        next unless action

        result = handle_action(action)
        break if result == :quit
      end
    end

    private

    def read_key
      $stdin.raw do |io|
        char = io.getc
        if char == "\e"
          rest = begin
            io.read_nonblock(3)
          rescue StandardError
            ''
          end
          char + rest
        else
          char
        end
      end
    end

    def relative_path(absolute)
      absolute.sub("#{@library_path}/", '')
    end

    def display_name(relative)
      File.basename(relative, '.*').sub(/\A\d+[\s.\-_]+/, '')
    end

    def render(title = "wavesync set #{@set.name}")
      @ui.clear
      puts @ui.color(title, :primary)
      puts

      if @set.tracks.empty?
        puts @ui.color('  (no tracks)', :secondary)
      else
        @set.tracks.each_with_index do |track, i|
          render_track(i, relative_path(track), i == @selected)
        end
      end

      puts
      puts @ui.color('[↑↓] navigate  [a] add  [u] up  [d] down  [r] remove  [s] save  [c] cancel', :secondary)
    end

    def render_track(index, relative, selected)
      name = display_name(relative)
      folder = File.dirname(relative)
      color = selected ? :highlight : :extra
      marker = selected ? "▶ #{index + 1}." : "  #{index + 1}."
      puts "#{@ui.color(marker, color)} #{@ui.color(name, selected ? :highlight : :primary)}"
      puts @ui.color("     #{folder}", selected ? :highlight : :tertiary) unless folder == '.'
    end

    def handle_action(action)
      case action
      when :cursor_up
        @selected = [@selected - 1, 0].max unless @set.tracks.empty?
      when :cursor_down
        @selected = [@selected + 1, @set.tracks.size - 1].min unless @set.tracks.empty?
      when :add        then add_track
      when :remove     then remove_track
      when :move_up    then move_track(:up)
      when :move_down  then move_track(:down)
      when :save
        @set.save
        path = Set.set_path(@library_path, @set.name)
        puts @ui.color("Saved '#{@set.name}' to #{path}.", :primary)
        :quit
      when :quit
        :quit
      end
    end

    def audio_files
      @audio_files ||= Audio.find_all(@library_path)
    end

    def add_track
      if audio_files.empty?
        puts @ui.color('No audio files found in library.', :highlight)
        sleep 1
        return
      end

      choices = audio_files.map { |file| { name: relative_path(file), value: file } }

      render("wavesync set #{@set.name} — add track")
      puts
      picked = @prompt.select('Select a track to add:', choices, cycle: true, filter: true, per_page: 20)

      insert_at = @selected.nil? ? 0 : @selected + 1
      @set.tracks.insert(insert_at, picked)
      @selected = insert_at
    end

    def remove_track
      return if @set.tracks.empty? || @selected.nil?

      @set.remove_track(@selected)
      @selected = if @set.tracks.empty?
                    nil
                  else
                    [@selected, @set.tracks.size - 1].min
                  end
    end

    def move_track(direction)
      return if @set.tracks.size < 2 || @selected.nil?

      if direction == :up
        @set.move_up(@selected)
        @selected = [@selected - 1, 0].max
      else
        @set.move_down(@selected)
        @selected = [@selected + 1, @set.tracks.size - 1].min
      end
    end
  end
end
