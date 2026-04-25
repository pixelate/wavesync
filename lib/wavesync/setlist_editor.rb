# frozen_string_literal: true
# rbs_inline: enabled

require 'tty-prompt'
require 'io/console'
require 'stringio'
require_relative 'logger'

module Wavesync
  class SetlistEditor
    KEY_MAP = {
      'a' => :add,
      'u' => :move_up,
      'd' => :move_down,
      'r' => :remove,
      'q' => :quit,
      ' ' => :toggle_play,
      'j' => :jump_to_next_cue,
      "\e[A" => :cursor_up,
      "\e[B" => :cursor_down
    }.freeze

    attr_accessor :player_state #: Symbol
    attr_reader :selected, :setlist, :ui #: untyped
    attr_writer :player_track, :player_index, :player_offset, :player_started_at, :player_pid

    #: (Setlist setlist, String library_path) -> void
    def initialize(setlist, library_path)
      @setlist = setlist #: Setlist
      @library_path = library_path #: String
      Logger.configure(@library_path)
      @prompt = TTY::Prompt.new(interrupt: :exit, active_color: :red) #: untyped
      @ui = UI.new #: UI
      @selected = @setlist.tracks.empty? ? nil : 0 #: Integer?
      @player_pid = nil #: Integer?
      @player_track = nil #: String?
      @player_index = nil #: Integer?
      @player_state = :stopped #: Symbol
      @player_offset = 0 #: Numeric
      @player_started_at = nil #: Time?
    end

    #: () -> void
    def run
      enter_fullscreen
      loop do
        check_player
        render
        action = KEY_MAP[read_key]
        next unless action

        result = handle_action(action)
        break if result == :quit
      end
    ensure
      exit_fullscreen
      stop_playback
    end

    #: (String? path) -> (String | Integer)?
    def track_bpm(path)
      return nil if path.nil?

      @track_bpms ||= {} #: Hash[String, (String | Integer)?]
      return @track_bpms[path] if @track_bpms.key?(path)

      @track_bpms[path] = begin
        Audio.new(path).bpm
      rescue StandardError => e
        Logger.log_error(e, call_site: 'SetlistEditor#track_bpm', arguments: { path: })
        nil
      end
    end

    #: (String? path) -> Float?
    def track_duration(path)
      return nil if path.nil?

      @track_durations ||= {} #: Hash[String, Float?]
      return @track_durations[path] if @track_durations.key?(path)

      @track_durations[path] = begin
        Audio.new(path).duration
      rescue StandardError => e
        Logger.log_error(e, call_site: 'SetlistEditor#track_duration', arguments: { path: })
        nil
      end
    end

    #: (String? path) -> Array[Float]
    def track_cue_fractions(path)
      return [] if path.nil?

      @track_cue_fractions ||= {} #: Hash[String, Array[Float]]
      return @track_cue_fractions[path] if @track_cue_fractions.key?(path)

      @track_cue_fractions[path] = begin
        audio = Audio.new(path)
        sample_rate = audio.sample_rate
        duration = audio.duration
        if sample_rate && duration&.positive?
          audio.cue_points.map { |cue_point| cue_point[:sample_offset].to_f / sample_rate / duration }
        else
          [] #: Array[Float]
        end
      rescue StandardError => e
        Logger.log_error(e, call_site: 'SetlistEditor#track_cue_fractions', arguments: { path: })
        [] #: Array[Float]
      end
    end

    #: ((String | Integer)? source_bpm, (String | Integer)? target_bpm) -> Float?
    def pitch_shift_semitones(source_bpm, target_bpm)
      return nil unless source_bpm && target_bpm

      source = source_bpm.to_f
      target = target_bpm.to_f
      return nil if source.zero?

      12.0 * Math.log2(target / source)
    end

    #: (Float semitones) -> String
    def format_pitch_shift(semitones)
      sign = semitones >= 0 ? '+' : ''
      "#{sign}#{semitones.round(2)}"
    end

    private

    #: () -> void
    def enter_fullscreen
      print "\e[?1049h" # enter alternate screen buffer
      print "\e[?25l"   # hide cursor
    end

    #: () -> void
    def exit_fullscreen
      print "\e[?25h"   # show cursor
      print "\e[?1049l" # exit alternate screen buffer
    end

    #: (StringIO buffer) -> void
    def flush_render(buffer)
      $stdout.print "\e[H"
      lines = buffer.string.lines
      lines.each_with_index do |line, i|
        terminator = i < lines.size - 1 ? "\n" : ''
        $stdout.print "\e[K#{line.chomp}#{terminator}"
      end
      $stdout.print "\e[J"
    end

    #: () -> String?
    def read_key
      $stdin.raw do |io|
        ready = io.wait_readable(0.5)
        return nil unless ready

        char = io.getc || ''
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

    #: (String absolute) -> String
    def relative_path(absolute)
      absolute.sub("#{@library_path}/", '')
    end

    #: (Float? seconds) -> String?
    def format_duration(seconds)
      return nil unless seconds

      total_seconds = seconds.to_i
      mins = total_seconds / 60
      secs = total_seconds % 60
      "#{mins}:#{secs.to_s.rjust(2, '0')}"
    end

    #: () -> Float
    def playback_elapsed
      case @player_state
      when :playing
        (@player_offset + (Time.now - @player_started_at)).to_f
      when :paused
        @player_offset.to_f
      else
        0.0
      end
    end

    #: () -> Integer
    def terminal_width
      IO.console&.winsize&.last || 80
    rescue StandardError
      80
    end

    #: (String? string) -> Integer
    def visible_length(string)
      return 0 unless string

      string.gsub(/\e\[[0-9;]*[A-Za-z]/, '').length
    end

    #: (Float elapsed, Float total_duration, Integer bar_width, ?cue_fractions: Array[Float]) -> String
    def playback_bar(elapsed, total_duration, bar_width, cue_fractions: [])
      ratio = total_duration.positive? ? [elapsed / total_duration, 1.0].min : 0.0
      filled = (ratio * bar_width).round

      bar = Array.new(bar_width) { |i| i < filled ? '█' : '░' }

      cue_position_colors = {} #: Hash[Integer, Symbol]
      cue_fractions.each do |fraction|
        position = (fraction * (bar_width - 1)).round.clamp(0, bar_width - 1)
        cue_position_colors[position] = position == filled ? :highlight : :surface
      end
      cue_position_colors.each_key { |position| bar[position] = '◆' }

      result = +''
      run_start = 0
      while run_start < bar_width
        if cue_position_colors.key?(run_start)
          result << @ui.color(bar[run_start], cue_position_colors[run_start])
          run_start += 1
        else
          run_end = run_start
          run_end += 1 while run_end < bar_width && !cue_position_colors.key?(run_end)
          result << @ui.color((bar[run_start...run_end] || []).join, :surface)
          run_start = run_end
        end
      end
      result
    end

    #: (Float elapsed, Float total_duration) -> String
    def remaining_display(elapsed, total_duration)
      remaining = [total_duration - elapsed, 0.0].max
      "-#{format_duration(remaining) || '0:00'}"
    end

    #: (String relative) -> String
    def display_name(relative)
      File.basename(relative, '.*').sub(/\A\d+[\s.\-_]+/, '')
    end

    #: (?String title) -> void
    def render(title = "wavesync setlist #{@setlist.name}")
      buffer = StringIO.new
      $stdout = buffer

      header = @ui.color(title, :primary)
      total_duration = @setlist.tracks.sum { |track_path| track_duration(track_path) || 0.0 }

      duration_widths = @setlist.tracks.map { |track_path| format_duration(track_duration(track_path))&.length || 0 }
      duration_widths << (format_duration(total_duration)&.length || 0)
      player_duration = @player_index ? track_duration(@setlist.tracks[@player_index]) : nil
      duration_widths << remaining_display(0.0, player_duration).length if player_duration
      duration_col_width = duration_widths.max || 0

      if @setlist.tracks.any? && total_duration.positive?
        track_label = @setlist.tracks.size == 1 ? 'track' : 'tracks'
        track_count_part = @ui.color("#{@setlist.tracks.size} #{track_label}", :secondary)
        duration_part = @ui.color(format_duration(total_duration).to_s.rjust(duration_col_width), :secondary)
        summary = "#{track_count_part}   #{duration_part}"
        gap = [terminal_width - visible_length(header) - visible_length(summary), 2].max
        puts "#{header}#{' ' * gap}#{summary}"
      else
        puts header
      end

      puts

      if @setlist.tracks.empty?
        puts @ui.color('  (no tracks)', :secondary)
      else
        @setlist.tracks.each_with_index do |track, i|
          current_bpm = track_bpm(track)
          current_duration = track_duration(track)
          pitch_shift = pitch_shift_semitones(current_bpm, track_bpm(@setlist.tracks[i + 1]))
          render_track(i, relative_path(track), i == @selected, i == @player_index,
                       bpm: current_bpm, pitch_shift: pitch_shift, duration: current_duration,
                       duration_col_width: duration_col_width, cue_fractions: track_cue_fractions(track))
        end
      end

      puts
      puts @ui.color('[↑↓] navigate [space] play/pause [j] next cue [a] add [u] up [d] down [r] remove [q] quit',
                     :secondary)
    ensure
      $stdout = STDOUT
      flush_render(buffer)
    end

    #: (Integer index, String relative, bool selected, bool playing, ?bpm: (String | Integer)?, ?pitch_shift: Float?, ?duration: Float?, ?duration_col_width: Integer, ?cue_fractions: Array[Float]) -> void
    def render_track(index, relative, selected, playing, bpm: nil, pitch_shift: nil, duration: nil, duration_col_width: 0, cue_fractions: [])
      name = display_name(relative)
      folder = File.dirname(relative)
      icon = if playing
               @player_state == :paused ? '⏸' : '▶'
             else
               ' '
             end
      name_color = selected ? :highlight : :primary
      index_color = selected ? :highlight : :extra
      bpm_color = selected ? :highlight : :secondary
      meta_color = selected ? :highlight : :tertiary

      colored_icon = @ui.color(icon, :surface)
      colored_index = @ui.color("#{index + 1}.", index_color)
      colored_name = @ui.color(name, name_color)
      bpm_label = bpm ? " · #{@ui.color("#{bpm} bpm", bpm_color)}" : ''
      left_line = "#{colored_icon} #{colored_index} #{colored_name}#{bpm_label}"

      folder_part = folder == '.' ? nil : @ui.color(folder, meta_color)
      elapsed = playing && duration ? playback_elapsed : nil
      duration_str = if elapsed && duration
                       @ui.color(remaining_display(elapsed, duration).rjust(duration_col_width), meta_color)
                     elsif !playing
                       format_duration(duration)&.then { @ui.color(_1.rjust(duration_col_width), meta_color) }
                     end
      right_line = [folder_part, duration_str].compact.join('   ')

      if right_line.empty?
        puts left_line
      else
        gap = terminal_width - visible_length(left_line) - visible_length(right_line)
        if gap >= 2
          puts "#{left_line}#{' ' * gap}#{right_line}"
        else
          puts left_line
          indent = '     '
          if folder_part && duration_str
            second_gap = [terminal_width - indent.length - visible_length(folder_part) - visible_length(duration_str), 2].max
            puts "#{indent}#{folder_part}#{' ' * second_gap}#{duration_str}"
          else
            puts "#{indent}#{folder_part || duration_str}"
          end
        end
      end

      if playing && @player_state != :stopped && duration
        bar_width = [terminal_width - 5, 20].max
        puts "     #{playback_bar(playback_elapsed, duration, bar_width, cue_fractions: cue_fractions)}"
      end

      return unless pitch_shift

      puts "     #{@ui.color("↓ #{format_pitch_shift(pitch_shift)} st", :secondary)}"
    end

    #: (Symbol action) -> Symbol?
    def handle_action(action)
      case action
      when :cursor_up
        @selected = [@selected - 1, 0].max unless @setlist.tracks.empty?
        nil
      when :cursor_down
        @selected = [@selected + 1, @setlist.tracks.size - 1].min unless @setlist.tracks.empty?
        nil
      when :toggle_play
        toggle_playback
        nil
      when :add
        add_track
        nil
      when :remove
        remove_track
        nil
      when :move_up
        move_track(:up)
        nil
      when :move_down
        move_track(:down)
        nil
      when :jump_to_next_cue
        jump_to_next_cue
        nil
      when :quit
        @setlist.save
        :quit
      end
    end

    #: () -> void
    def toggle_playback
      return if @selected.nil?

      track = @setlist.tracks[@selected]

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

    #: (String track, ?Numeric offset, ?player_index: Integer?) -> void
    def start_player(track, offset = 0, player_index: @selected)
      ffplay = Wavesync::FFMPEG.ffplay_binary
      args = [ffplay, '-nodisp', '-autoexit', '-loglevel', 'quiet', '-probesize', '32', '-analyzeduration', '0']
      args += ['-ss', offset.to_s] if offset.positive?
      args << track
      @player_pid = spawn(*args, out: File::NULL, err: File::NULL)
      @player_track = track
      @player_index = player_index
      @player_offset = offset
      @player_started_at = Time.now
      @player_state = :playing
    end

    #: () -> void
    def jump_to_next_cue
      return unless @player_track

      duration = track_duration(@player_track)
      return unless duration&.positive?

      fractions = track_cue_fractions(@player_track)
      return if fractions.empty?

      elapsed = playback_elapsed
      sorted_fractions = fractions.sort
      next_fraction = sorted_fractions.find { |fraction| fraction * duration > elapsed + 0.05 }
      next_fraction ||= sorted_fractions.first

      kill_player
      start_player(@player_track, next_fraction * duration, player_index: @player_index)
    end

    #: () -> void
    def kill_player
      return unless @player_pid

      player_pid = @player_pid
      Process.kill('TERM', @player_pid)
      @player_pid = nil
    rescue Errno::ESRCH => e
      Logger.log_error(e, call_site: 'SetlistEditor#kill_player', arguments: { player_pid: })
      @player_pid = nil
    end

    #: () -> void
    def stop_playback
      kill_player
      @player_track = nil
      @player_index = nil
      @player_state = :stopped
      @player_offset = 0
      @player_started_at = nil
    end

    #: () -> void
    def check_player
      return unless @player_pid

      player_pid = @player_pid
      result = Process.waitpid(@player_pid, Process::WNOHANG)
      return unless result

      @player_pid = nil
      @player_track = nil
      @player_index = nil
      @player_state = :stopped
      @player_offset = 0
      advance_and_play
    rescue Errno::ECHILD => e
      Logger.log_error(e, call_site: 'SetlistEditor#check_player', arguments: { player_pid: })
      @player_pid = nil
      @player_track = nil
      @player_index = nil
      @player_state = :stopped
      @player_offset = 0
      advance_and_play
    end

    #: () -> void
    def advance_and_play
      return if @selected.nil? || @selected >= @setlist.tracks.size - 1

      @selected += 1
      start_player(@setlist.tracks[@selected])
    end

    #: () -> Array[String]
    def audio_files
      @audio_files ||= Audio.find_all(@library_path)
    end

    #: () -> void
    def add_track
      if audio_files.empty?
        puts @ui.color('No audio files found in library.', :highlight)
        sleep 1
        return
      end

      choices = audio_files.map { |file| { name: relative_path(file), value: file } }

      render("wavesync setlist #{@setlist.name} — add track")
      puts
      picked = @prompt.select('Select a track to add:', choices, cycle: true, filter: true, per_page: 20)

      insert_at = @selected.nil? ? 0 : @selected + 1
      @setlist.tracks.insert(insert_at, picked)
      @selected = insert_at
    end

    #: () -> void
    def remove_track
      return if @setlist.tracks.empty? || @selected.nil?

      stop_playback if @player_track == @setlist.tracks[@selected]
      @setlist.remove_track(@selected)
      @selected = if @setlist.tracks.empty?
                    nil
                  else
                    [@selected, @setlist.tracks.size - 1].min
                  end
    end

    #: (Symbol direction) -> void
    def move_track(direction)
      return if @setlist.tracks.size < 2 || @selected.nil?

      if direction == :up
        @setlist.move_up(@selected)
        @selected = [@selected - 1, 0].max
      else
        @setlist.move_down(@selected)
        @selected = [@selected + 1, @setlist.tracks.size - 1].min
      end
    end

    public :handle_action, :advance_and_play, :kill_player, :check_player,
           :display_name, :relative_path, :format_duration, :playback_elapsed,
           :visible_length, :playback_bar, :selected, :setlist, :ui
  end
end
