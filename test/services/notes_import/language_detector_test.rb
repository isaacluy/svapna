require "test_helper"

class NotesImport::LanguageDetectorTest < ActiveSupport::TestCase
  test "detects Spanish from its function words" do
    assert_equal "es", detect(
      "Anoche soñé que estaba en la casa de mi abuela y que todo el jardín se había llenado de agua."
    )
  end

  test "detects English from its function words" do
    assert_equal "en", detect(
      "Last night I dreamed that I was in my grandmother's house and that the whole garden had filled with water."
    )
  end

  test "detects Spanish even with accents removed" do
    assert_equal "es", detect("Anoche sone que estaba en la casa de mi abuela y que todo el jardin se habia llenado")
  end

  test "falls back rather than guessing on text with no signal" do
    # Lorem ipsum is neither language; guessing would put it in the wrong stemmer.
    assert_equal NotesImport::LanguageDetector::DEFAULT,
                 detect("Lorem ipsum dolor sit amet consectetur adipisicing elit sed")
  end

  test "falls back on empty text" do
    assert_equal NotesImport::LanguageDetector::DEFAULT, detect("")
  end

  test "only returns languages that have a text search configuration" do
    assert_includes Entry::LANGUAGES, detect("the quick brown fox and the lazy dog in a house")
  end

  private
    def detect(text) = NotesImport::LanguageDetector.call(text)
end
