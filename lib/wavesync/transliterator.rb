# frozen_string_literal: true
# rbs_inline: enabled

module Wavesync
  module Transliterator
    COMBINING_MARKS = /\p{Mn}/

    #: (String string) -> String
    def self.transliterate(string)
      string
        .unicode_normalize(:nfd)
        .gsub(COMBINING_MARKS, '')
    end
  end
end
