module NotesImport
  # Picks a language by counting how many of the text's words are stopwords in
  # each candidate language. Function words are the most reliable signal in
  # paragraph-length prose, and this needs no gem and no native extension.
  module LanguageDetector
    DEFAULT = "es".freeze
    # Below this, the text is too short or too unusual to call -- lorem ipsum,
    # a single line, a list of names -- so fall back rather than guess.
    MINIMUM_RATIO = 0.08

    module_function

    def stopwords
      @stopwords ||= Entry::LANGUAGES.index_with do |language|
        path = Rails.root.join("config/stopwords/#{language}.txt")
        path.readlines(chomp: true)
            .reject { |line| line.blank? || line.start_with?("#") }
            .map { |word| Text.fold(word) }
            .to_set
      end
    end

    def call(text)
      words = Text.words(text)
      return DEFAULT if words.empty?

      scores = stopwords.transform_values do |list|
        words.count { |word| list.include?(word) } / words.size.to_f
      end

      best, ratio = scores.max_by { |_language, score| score }
      ratio >= MINIMUM_RATIO ? best : DEFAULT
    end

    def reset!
      @stopwords = nil
    end
  end
end
