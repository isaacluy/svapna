module Analytics
  # The editable stopword lists in config/stopwords/. Shared with
  # NotesImport::LanguageDetector, so a word added there affects both.
  module Stopwords
    module_function

    def available = @available ||= Dir[Rails.root.join("config/stopwords/*.txt")].map { |p| File.basename(p, ".txt") }.sort

    # Accent-folded, because word_vector keeps accents: the list holds "mas" and
    # has to match "más".
    def for(languages)
      Array(languages).map(&:to_s).select { |l| available.include?(l) }.flat_map { |l| list(l) }.to_set
    end

    def list(language)
      @lists ||= {}
      @lists[language] ||= Rails.root.join("config/stopwords/#{language}.txt")
                                .readlines(chomp: true)
                                .reject { |line| line.blank? || line.start_with?("#") }
                                .map { |word| NotesImport::Text.fold(word) }
    end

    def reset! = @available = @lists = nil
  end
end
