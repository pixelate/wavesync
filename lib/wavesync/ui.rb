# frozen_string_literal: true

require 'tty-cursor'

module Wavesync
  class UI
    def initialize
      @cursor = TTY::Cursor
      @sticky_lines = []
    end

    def file_progress(filename)
      path = Pathname.new(filename)
      file_stem = path.basename(path.extname).to_s
      parent_name = path.parent.basename.to_s
      sticky(parent_name, 1)
      sticky(file_stem, 2)
    end

    def sync_progress(index, total_count, skipped_count, conversion_count)
      line = "wavesync #{index + 1}/#{total_count} (#{skipped_count} skipped/#{conversion_count} converted)"
      sticky(line, 0)
    end

    private

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
