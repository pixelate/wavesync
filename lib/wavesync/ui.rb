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

    def conversion_progress(source_sample_rate, target_sample_rate, source_file_type, target_file_type)
      target_sample_rate = source_sample_rate if target_sample_rate.nil?
      target_file_type = source_file_type if target_file_type.nil?

      formatted_line = in_color(
        "Converting #{source_file_type} (#{source_sample_rate}) ⇢ #{target_file_type} (#{target_sample_rate})", :highlight
      )
      sticky(formatted_line, 3)
    end

    def copy(source_sample_rate, source_file_type)
      sticky(in_color("Copying #{source_file_type} (#{source_sample_rate})", :highlight), 3)
    end

    def skip
      sticky(in_color('↷ Skipping, already synced', :highlight), 3)
    end

    private

    def in_color(string, key)
      Rainbow(string).color(THEME[key])
    end

    def sticky(text, index)
      @sticky_lines[index] = text
      redraw
    end

    def redraw
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
      puts @sticky_lines.join("\n")
    end
  end
end
