# frozen_string_literal: true

require 'tty-cursor'
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

    def initialize
      @cursor = TTY::Cursor
      @sticky_lines = []
    end

    def file_progress(filename)
      path = Pathname.new(filename)
      file_stem = path.basename(path.extname).to_s
      parent_name = path.parent.basename.to_s
      sticky(in_color(parent_name, :secondary), 1)
      sticky(in_color(file_stem, :tertiary), 2)
    end

    def sync_progress(index, total_count, device)
      parts = [
        in_color("wavesync #{device.name}", :primary),
        in_color("#{index + 1}/#{total_count}", :extra)
      ]

      sticky(parts.join(' '), 0)
    end

    def conversion_progress(source_format, target_format)
      effective = source_format.merge(target_format)

      source_info = audio_info(source_format.sample_rate, source_format.bit_depth)
      target_info = audio_info(effective.sample_rate, effective.bit_depth)

      formatted_line = in_color(
        "Converting #{source_format.file_type} (#{source_info}) ⇢ #{effective.file_type} (#{target_info})", :highlight
      )
      sticky(formatted_line, 3)
    end

    def copy(source_format)
      info = audio_info(source_format.sample_rate, source_format.bit_depth)

      sticky(in_color("Copying #{source_format.file_type} (#{info})", :highlight), 3)
    end

    def skip
      sticky(in_color('↷ Skipping, already synced', :highlight), 3)
    end

    def bpm(tbpm)
      if tbpm.nil?
        sticky('', 4)
      else
        sticky("#{tbpm}bpm", 4)
      end
    end

    def analyze_progress(index, total_count)
      parts = [
        in_color('wavesync analyze', :primary),
        in_color("#{index + 1}/#{total_count}", :extra)
      ]
      sticky(parts.join(' '), 0)
    end

    def analyze_skip(file, bpm)
      set_analyze_file_stickies(file, in_color("↷ #{bpm} BPM already set", :highlight))
    end

    def analyze_result(file, bpm)
      label = bpm ? in_color("#{bpm} BPM", :highlight) : in_color('No BPM detected', :highlight)
      set_analyze_file_stickies(file, label)
    end

    def color(text, key)
      in_color(text, key)
    end

    def clear
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
    end

    private

    def audio_info(sample_rate, bit_depth)
      [
        sample_rate_to_khz(sample_rate),
        bit_depth
      ].compact.join('/')
    end

    def in_color(string, key)
      Rainbow(string).color(THEME[key])
    end

    def sticky(text, index)
      set_sticky(text, index)
      redraw
    end

    def set_sticky(text, index)
      @sticky_lines[index] = text
    end

    def set_analyze_file_stickies(file, label)
      path = Pathname.new(file)
      set_sticky(in_color(path.parent.basename.to_s, :secondary), 1)
      set_sticky(in_color(path.basename(path.extname).to_s, :tertiary), 2)
      set_sticky(label, 3)
      redraw
    end

    def redraw
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
      puts @sticky_lines.join("\n")
    end

    def sample_rate_to_khz(rate)
      khz = rate.to_f / 1000
      (khz % 1).zero? ? khz.to_i.to_s : khz.round(1).to_s
    end
  end
end
