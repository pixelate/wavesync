# frozen_string_literal: true
# rbs_inline: enabled

require 'tty-cursor'
require 'tty-prompt'
require 'rainbow'

module Wavesync
  class UI
    THEME = {
      primary: :lightgray,
      secondary: :darkgray,
      tertiary: :dimgray,
      highlight: :orangered,
      surface: :hotpink,
      extra: :deepskyblue
    }.freeze

    #: () -> void
    def initialize
      @cursor = TTY::Cursor #: untyped
      @sticky_lines = [] #: Array[String]
      @prompt = TTY::Prompt.new(interrupt: :exit, active_color: :red) #: untyped
    end

    #: (String filename) -> void
    def file_progress(filename)
      path = Pathname.new(filename)
      file_stem = path.basename(path.extname).to_s
      parent_name = path.parent.basename.to_s
      sticky(in_color(parent_name, :secondary), 1)
      sticky(in_color(file_stem, :tertiary), 2)
    end

    #: (Integer index, Integer total_count, Device device) -> void
    def sync_progress(index, total_count, device)
      parts = [
        in_color("wavesync #{device.name}", :primary),
        in_color("#{index + 1}/#{total_count}", :extra)
      ]

      sticky(parts.join(' '), 0)
    end

    #: (AudioFormat source_format, AudioFormat target_format) -> void
    def conversion_progress(source_format, target_format)
      effective = source_format.merge(target_format)

      source_info = audio_info(source_format)
      target_info = target_audio_info(effective)

      formatted_line = in_color(
        "Converting #{source_format.file_type} (#{source_info}) ⇢ #{effective.file_type} (#{target_info})", :highlight
      )
      sticky(formatted_line, 3)
    end

    #: (AudioFormat source_format) -> void
    def copy(source_format)
      info = audio_info(source_format)

      sticky(in_color("Copying #{source_format.file_type} (#{info})", :highlight), 3)
    end

    #: () -> void
    def skip
      sticky(in_color('↷ Skipping, already synced', :highlight), 3)
    end

    #: ((String | Integer)? tbpm, ?original_bars: Integer?, ?target_bars: Integer?) -> void
    def bpm(tbpm, original_bars: nil, target_bars: nil)
      if tbpm.nil?
        sticky('', 4)
      elsif original_bars && target_bars
        bar_info = original_bars == target_bars ? "#{original_bars} bars" : "#{original_bars} → #{target_bars} bars"
        sticky("#{tbpm} bpm · #{bar_info}", 4)
      else
        sticky("#{tbpm} bpm", 4)
      end
    end

    #: (Integer index, Integer total_count) -> void
    def analyze_progress(index, total_count)
      parts = [
        in_color('wavesync analyze', :primary),
        in_color("#{index + 1}/#{total_count}", :extra)
      ]
      sticky(parts.join(' '), 0)
    end

    #: (String file, (String | Integer)? bpm) -> void
    def analyze_skip(file, bpm)
      set_analyze_file_stickies(file, in_color("↷ #{bpm} BPM already set", :highlight))
    end

    #: (String file, Integer? bpm) -> void
    def analyze_result(file, bpm)
      label = bpm ? in_color("#{bpm} BPM", :highlight) : in_color('No BPM detected', :highlight)
      set_analyze_file_stickies(file, label)
    end

    #: (String message) -> bool
    def confirm(message)
      print in_color(message, :secondary)
      response = $stdin.gets.to_s.strip.downcase
      response == 'y'
    end

    #: (String label, Array[String] options) -> String
    def select(label, options)
      @prompt.select(label, options, cycle: true)
    end

    #: (String text, Symbol key) -> String
    def color(text, key)
      in_color(text, key)
    end

    #: () -> void
    def clear
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
    end

    MP3_BITRATE_KBPS = 192

    private

    #: (AudioFormat format) -> String
    def audio_info(format)
      quality = format.file_type == 'mp3' ? format.bitrate&.to_s : format.bit_depth&.to_s
      [
        sample_rate_to_khz(format.sample_rate),
        quality
      ].compact.join('/')
    end

    #: (AudioFormat format) -> String
    def target_audio_info(format)
      quality = format.file_type == 'mp3' ? MP3_BITRATE_KBPS.to_s : format.bit_depth&.to_s
      [
        sample_rate_to_khz(format.sample_rate),
        quality
      ].compact.join('/')
    end

    #: (String string, Symbol key) -> String
    def in_color(string, key)
      Rainbow(string).color(THEME[key])
    end

    #: (String text, Integer index) -> void
    def sticky(text, index)
      set_sticky(text, index)
      redraw
    end

    #: (String text, Integer index) -> void
    def set_sticky(text, index)
      @sticky_lines[index] = text
    end

    #: (String file, String label) -> void
    def set_analyze_file_stickies(file, label)
      path = Pathname.new(file)
      set_sticky(in_color(path.parent.basename.to_s, :secondary), 1)
      set_sticky(in_color(path.basename(path.extname).to_s, :tertiary), 2)
      set_sticky(label, 3)
      redraw
    end

    #: () -> void
    def redraw
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
      puts @sticky_lines.join("\n")
    end

    #: (Integer? rate) -> String?
    def sample_rate_to_khz(rate)
      return nil unless rate

      khz = rate.to_f / 1000
      (khz % 1).zero? ? khz.to_i.to_s : khz.round(1).to_s
    end
  end
end
