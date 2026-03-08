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
      ' ' => :toggle_play,
      "\e[A" => :cursor_up,
      "\e[B" => :cursor_down
    }.freeze

    def initialize(set, library_path)
      @set = set
      @library_path = library_path
      @prompt = TTY::Prompt.new(interrupt: :exit, active_color: :red)
      @ui = UI.new
      @selected = @set.tracks.empty? ? nil : 0
      @player_pid = nil
      @player_track = nil
      @player_state = :stopped
      @player_offset = 0
      @player_started_at = nil
    end

    def run
      loop do
        check_player
        render
        action = KEY_MAP[read_key]
        next unless action

        result = handle_action(action)
        break if result == :quit
      end
    ensure
      stop_playback
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
          render_track(i, relative_path(track), i == @selected, track == @player_track)
        end
      end

      puts
      puts @ui.color('[↑↓] navigate  [space] play/pause  [a] add  [u] up  [d] down  [r] remove  [s] save  [c] cancel',
                     :secondary)
    end

    def render_track(index, relative, selected, playing)
      name = display_name(relative)
      folder = File.dirname(relative)
      icon = if playing
               @player_state == :paused ? '⏸' : '▶'
             else
               ' '
             end
      puts "#{@ui.color(icon, :surface)} #{@ui.color("#{index + 1}.", selected ? :highlight : :extra)} #{@ui.color(name, selected ? :highlight : :primary)}"
      puts @ui.color("     #{folder}", selected ? :highlight : :tertiary) unless folder == '.'
    end

    def handle_action(action)
      case action
      when :cursor_up
        @selected = [@selected - 1, 0].max unless @set.tracks.empty?
      when :cursor_down
        @selected = [@selected + 1, @set.tracks.size - 1].min unless @set.tracks.empty?
      when :toggle_play  then toggle_playback
      when :add          then add_track
      when :remove       then remove_track
      when :move_up      then move_track(:up)
      when :move_down    then move_track(:down)
      when :save
        @set.save
        path = Set.set_path(@library_path, @set.name)
        puts @ui.color("Saved '#{@set.name}' to #{path}.", :primary)
        :quit
      when :quit
        :quit
      end
    end

    def toggle_playback
      return if @selected.nil?

      track = @set.tracks[@selected]

      if @player_track == track
        case @player_state
        when :playing
          @player_offset += Time.now - @player_started_at
          kill_player
          @player_state = :paused
        when :paused
          start_player(track, @player_offset)
        end
      else
        stop_playback
        start_player(track)
      end
    end

    def start_player(track, offset = 0)
      ffplay = FFMPEG.ffmpeg_binary.sub('ffmpeg', 'ffplay')
      args = [ffplay, '-nodisp', '-autoexit', '-loglevel', 'quiet', '-probesize', '32', '-analyzeduration', '0']
      args += ['-ss', offset.to_s] if offset.positive?
      args << track
      @player_pid = spawn(*args, out: File::NULL, err: File::NULL)
      @player_track = track
      @player_offset = offset
      @player_started_at = Time.now
      @player_state = :playing
    end

    def kill_player
      return unless @player_pid

      Process.kill('TERM', @player_pid)
      @player_pid = nil
    rescue Errno::ESRCH
      @player_pid = nil
    end

    def stop_playback
      kill_player
      @player_track = nil
      @player_state = :stopped
      @player_offset = 0
      @player_started_at = nil
    end

    def check_player
      return unless @player_pid

      result = Process.waitpid(@player_pid, Process::WNOHANG)
      return unless result

      @player_pid = nil
      @player_track = nil
      @player_state = :stopped
      @player_offset = 0
      advance_and_play
    rescue Errno::ECHILD
      @player_pid = nil
      @player_track = nil
      @player_state = :stopped
      @player_offset = 0
      advance_and_play
    end

    def advance_and_play
      return if @selected.nil? || @selected >= @set.tracks.size - 1

      @selected += 1
      start_player(@set.tracks[@selected])
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

      stop_playback if @player_track == @set.tracks[@selected]
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
