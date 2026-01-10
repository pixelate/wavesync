# frozen_string_literal: true

require 'tty-cursor'

module Wavesync
  class UI
    def initialize
      @cursor = TTY::Cursor
      @sticky_lines = []
    end

    def sticky(text, index)
      @sticky_lines[index] = text
      redraw
    end

    private

    def redraw
      print @cursor.clear_screen
      print @cursor.move_to(0, 0)
      puts @sticky_lines.join("\n")
    end
  end
end
