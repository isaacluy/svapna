require "test_helper"

class Analytics::WordFrequencyTest < ActiveSupport::TestCase
  setup do
    Entry.delete_all
    Entry.create!(body: "El mar y las montañas. El mar otra vez. Siempre el mar.", written_on: Date.current, language: "es")
    Entry.create!(body: "Las montañas eran altas.", written_on: Date.current - 1, language: "es")
  end

  test "counts occurrences and the entries each word appears in" do
    mar = row_for("mar")

    assert_equal 3, mar.occurrences, "'mar' appears three times"
    assert_equal 1, mar.entries, "all three are in one entry"
  end

  test "a word spanning entries is counted once per entry" do
    montanas = row_for("montañas")

    assert_equal 2, montanas.occurrences
    assert_equal 2, montanas.entries
  end

  test "keeps accents, so results read as real words" do
    assert_includes words, "montañas"
    assert_not_includes words, "montanas"
  end

  test "does not stem" do
    assert_not_includes words, "montan", "stems belong to search_vector, not counting"
  end

  test "excludes common words by default" do
    assert_not_includes words, "el"
    assert_not_includes words, "las"
    assert_not_includes words, "y"
  end

  test "stopword exclusion is accent-insensitive" do
    Entry.create!(body: "Más y más sueños", written_on: Date.current - 2, language: "es")

    # The list holds "mas"; the text says "más".
    assert_not_includes words, "más"
  end

  test "stopwords: :none keeps everything" do
    kept = words(stopwords: :none)

    assert_includes kept, "el"
    assert_includes kept, "mar"
  end

  test "an explicit list overrides the detected languages" do
    assert_includes words(stopwords: [ :en ]), "el", "the Spanish list is not applied"
  end

  test "ordered by occurrences, most frequent first" do
    counts = Analytics::WordFrequency.call.rows.map(&:occurrences)

    assert_equal counts.sort.reverse, counts
  end

  test "busiest is the most repeated word" do
    assert_equal "mar", Analytics::WordFrequency.call.busiest.word
  end

  test "scoping to a subset changes the counts" do
    only_second = Analytics::WordFrequency.call(scope: Entry.where(written_on: Date.current - 1))

    assert_equal 1, only_second.entries_count
    assert_includes only_second.rows.map(&:word), "altas"
    assert_not_includes only_second.rows.map(&:word), "mar"
  end

  test "excludes drafts by default, because the default scope is published" do
    Entry.create!(body: "Palabrota", written_on: Date.current, language: "es", status: :draft)

    assert_not_includes words, "palabrota"
  end

  test "stopwords are applied before the limit, so the top list is never padded with them" do
    top = Analytics::WordFrequency.call(limit: 2).rows.map(&:word)

    assert_equal 2, top.size
    assert_empty top & %w[el las y]
  end

  test "the limit is clamped to something sane" do
    assert_equal Analytics::WordFrequency::MAX_LIMIT, Analytics::WordFrequency.new(limit: 10_000).limit
    assert_equal 1, Analytics::WordFrequency.new(limit: 0).limit
    assert_equal 1, Analytics::WordFrequency.new(limit: -5).limit
    assert_equal 1, Analytics::WordFrequency.new(min_length: 0).min_length
  end

  test "min_length drops very short words" do
    assert_not_includes words(min_length: 4), "mar"
    assert_includes words(min_length: 4), "montañas"
  end

  test "an empty scope yields nothing rather than raising" do
    frequency = Analytics::WordFrequency.call(scope: Entry.none)

    assert_empty frequency.rows
    assert_equal 0, frequency.entries_count
    assert_nil frequency.busiest
    assert_predicate frequency, :empty?
  end

  test "the cache key changes when an entry changes" do
    before = Analytics::WordFrequency.new.send(:cache_key)
    Entry.first.update!(body: "Algo completamente distinto")

    assert_not_equal before, Analytics::WordFrequency.new.send(:cache_key),
      "a stale count would otherwise be served"
  end

  test "a quoted scope cannot break out of the ts_stat literal" do
    nasty = Entry.where(source: "'); DROP TABLE entries; --")

    assert_nothing_raised { Analytics::WordFrequency.call(scope: nasty).rows }
    assert Entry.exists?, "entries table should still be there"
  end

  private
    def words(**options) = Analytics::WordFrequency.call(**options).rows.map(&:word)
    def row_for(word) = Analytics::WordFrequency.call.rows.find { |r| r.word == word }
end
