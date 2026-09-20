module NotesImport
  # Decides whether an entry is important, from the editable keyword list in
  # config/import_keywords.yml.
  module Importance
    module_function

    def keywords
      @keywords ||= YAML.load_file(Rails.root.join("config/import_keywords.yml"))
                        .fetch("important")
                        .map { |word| Text.fold(word) }
    end

    def pattern
      @pattern ||= /\b(?:#{keywords.map { |w| Regexp.escape(w) }.join("|")})\b/
    end

    def important?(body)
      Text.fold(body).match?(pattern)
    end

    def reset!
      @keywords = @pattern = nil
    end
  end
end
