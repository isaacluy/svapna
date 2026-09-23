require "test_helper"

class VocabularyTest < ActiveSupport::TestCase
  setup do
    Entry.delete_all
    Entry.create!(body: "Soñé con montañas y con el mar", written_on: Date.current, language: "es")
    Entry.create!(body: "Una pesadilla muy larga", written_on: Date.current - 1, language: "es")
  end

  test "suggests the real word for a misspelling" do
    assert_includes Vocabulary.similar_to("montanhas"), "montañas"
    assert_includes Vocabulary.similar_to("pesadila"), "pesadilla"
  end

  test "suggestions keep their accents, because they come from word_vector" do
    assert_includes Vocabulary.similar_to("montanhas"), "montañas"
    assert_not_includes Vocabulary.similar_to("montanhas"), "montanas"
  end

  test "never suggests the word that was typed" do
    assert_not_includes Vocabulary.similar_to("montañas"), "montañas"
  end

  test "returns nothing for a word unlike anything written" do
    assert_empty Vocabulary.similar_to("xyzzy")
  end

  test "returns nothing for blank input" do
    assert_empty Vocabulary.similar_to("")
    assert_empty Vocabulary.similar_to(nil)
  end

  test "only draws on published entries" do
    Entry.create!(body: "Palabrota", written_on: Date.current, language: "es", status: :draft)

    assert_empty Vocabulary.similar_to("palabrotas")
  end

  test "respects the limit" do
    assert_operator Vocabulary.similar_to("montanhas", limit: 1).size, :<=, 1
  end

  test "a quote in the input cannot break out of the query" do
    assert_nothing_raised { Vocabulary.similar_to("mon'tanhas") }
    assert_nothing_raised { Vocabulary.similar_to("'; DROP TABLE entries; --") }
    assert Entry.exists?, "entries table should still be there"
  end
end
