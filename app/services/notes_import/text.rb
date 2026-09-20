module NotesImport
  # Shared text helpers. Kept separate so the parser, the language detector and
  # (later) word-frequency analysis all normalise identically.
  module Text
    module_function

    # Apple Notes emits CRLF, non-breaking spaces and narrow no-break spaces.
    # Left alone, a non-breaking space makes a divider line fail to match and an
    # entire entry silently merges into its neighbour.
    def normalize(text)
      text.to_s
          .unicode_normalize(:nfc)
          .gsub(/\r\n?/, "\n")
          .gsub(/[   ​﻿]/, " ")
    end

    # Strips diacritics so "Soñé" compares equal to "sone".
    def fold(text)
      text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
    end

    def words(text)
      fold(text).scan(/[a-z0-9]+(?:'[a-z]+)?/)
    end
  end
end
