require "test_helper"

# Exercises the generated columns and text search configurations directly.
# These are database behaviours, so nothing here is stubbed -- if Postgres stops
# doing this, search is broken no matter what the Ruby does.
class EntrySearchVectorTest < ActiveSupport::TestCase
  test "search_vector is populated by the database with no callback" do
    entry = Entry.create!(body: "Soñé con montañas", written_on: Date.current, language: "es")

    assert_predicate entry.reload.search_vector, :present?
  end

  test "search_vector is recomputed when the body changes" do
    entry = entries(:sueno_es)
    before = entry.reload.search_vector

    entry.update!(body: "Un texto completamente distinto sobre bicicletas")

    assert_not_equal before, entry.reload.search_vector
  end

  test "both vectors are read-only virtual columns" do
    virtual = Entry.columns.select(&:virtual?).map(&:name)

    assert_includes virtual, "search_vector"
    assert_includes virtual, "word_vector"
  end

  test "matching ignores accents" do
    assert_includes matching("sueno"), entries(:sueno_es),
      "unaccented query should find the accented source 'Sueños p.14'"
    assert_includes matching("montanas"), entries(:sueno_es)
  end

  test "matching ignores Spanish stemming differences" do
    assert_includes matching("montana"), entries(:sueno_es),
      "singular query should find the plural 'montañas'"
    assert_includes matching("sonar"), entries(:sueno_es),
      "infinitive should find the conjugated 'Soñé' / 'Soñaba'"
  end

  test "a query parsed under both configurations finds entries in either language" do
    results = Entry.where(
      "search_vector @@ (websearch_to_tsquery('public.svapna_es', :q) || websearch_to_tsquery('public.svapna_en', :q))",
      q: "running"
    )

    assert_includes results, entries(:dream_en)
  end

  test "websearch syntax survives malformed input instead of raising" do
    assert_nothing_raised { matching(%q("unclosed quote AND -)).to_a }
  end

  test "phrase search requires adjacency" do
    entry = Entry.create!(body: "Montañas altas", written_on: Date.current, language: "es")

    assert_includes matching(%q("montañas altas")), entry
    assert_not_includes matching(%q("altas montañas")), entry
  end

  # Worth knowing when a phrase search returns more than expected: the Spanish
  # configuration strips stopwords, so "con montañas" reduces to "montañas".
  test "stopwords drop out of a phrase" do
    assert_includes matching(%q("con montañas")), entries(:sueno_es)
    assert_includes matching(%q("montañas con")), entries(:sueno_es)
  end

  test "body outranks source" do
    # 'montañas' is in the body (weight A); 'p.14' only in the source (weight C).
    body_rank = rank_for(entries(:sueno_es), "montanas")
    source_rank = rank_for(entries(:sueno_es), "p.14")

    assert_operator body_rank, :>, source_rank
  end

  test "word_vector keeps accents and does not stem, so counts read as real words" do
    words = word_frequencies(Entry.where(id: entries(:sueno_es).id))

    assert_includes words, "montañas"
    assert_includes words, "soñé"
    assert_not_includes words, "montanas"
    assert_not_includes words, "montan"
  end

  test "an unsupported language falls back to simple rather than nulling the vector" do
    entry = Entry.new(body: "Sonho com montanhas", written_on: Date.current, language: "pt")
    entry.save!(validate: false)

    assert_predicate entry.reload.search_vector, :present?
  end

  test "the dedupe index blocks a repeated import but allows repeated drafts" do
    attrs = { body: "Mismo texto", written_on: Date.new(2026, 1, 1), language: "es" }

    Entry.create!(**attrs, import_id: 1)
    assert_raises(ActiveRecord::RecordNotUnique) { Entry.create!(**attrs, import_id: 2) }

    # No import_id: outside the partial index, so duplicates are fine.
    Entry.create!(**attrs)
    assert_nothing_raised { Entry.create!(**attrs) }
  end

  private
    def matching(query, config: "public.svapna_es")
      Entry.where("search_vector @@ websearch_to_tsquery(?, ?)", config, query)
    end

    def rank_for(entry, query)
      Entry.where(id: entry.id).pick(
        Arel.sql(Entry.sanitize_sql_array([
          "ts_rank_cd(search_vector, websearch_to_tsquery('public.svapna_es', ?))", query
        ]))
      )
    end

    def word_frequencies(scope)
      sql = Entry.connection.quote(scope.select(:word_vector).to_sql)
      Entry.connection.select_values("SELECT word FROM ts_stat(#{sql})")
    end
end
