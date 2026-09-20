require "test_helper"

class EntrySearchTest < ActiveSupport::TestCase
  # --- matching -------------------------------------------------------------

  test "an empty query browses everything published" do
    search = EntrySearch.new

    assert_not search.searching?
    assert_includes search.entries, entries(:sueno_es)
    assert_not_includes search.entries, entries(:unfinished), "drafts are excluded by default"
  end

  test "ignores accents" do
    assert_includes results("montanas"), entries(:sueno_es)
    assert_includes results("sueno"), entries(:sueno_es), "matches the accented source note"
  end

  test "ignores Spanish stemming differences" do
    assert_includes results("montana"), entries(:sueno_es)
    assert_includes results("sonar"), entries(:sueno_es)
  end

  test "a query is parsed under every language, so it crosses languages" do
    assert_includes results("running"), entries(:dream_en),
      "an English entry is findable even though the query is also parsed as Spanish"
  end

  test "supports quoted phrases" do
    entry = Entry.create!(body: "Montañas altas", written_on: Date.current, language: "es")

    assert_includes results(%q("montañas altas")), entry
    assert_not_includes results(%q("altas montañas")), entry
  end

  test "supports or and exclusion" do
    assert_includes results("montanas or running"), entries(:dream_en)
    assert_not_includes results("montanas -mar"), entries(:sueno_es)
  end

  test "malformed input returns nothing instead of raising" do
    assert_nothing_raised { results(%q("unclosed AND - or)) }
  end

  test "ranks a body match above a match only in the source note" do
    ranked = EntrySearch.new(q: "montanas or suenos").entries

    assert_equal entries(:sueno_es), ranked.first,
      "the entry whose body matches should outrank ones matching only the note title"
  end

  # --- filters --------------------------------------------------------------

  test "filters by tag" do
    entries(:sueno_es).tag!("important")

    search = EntrySearch.new(tag: "important")

    assert_equal [ entries(:sueno_es) ], search.entries
  end

  test "filters by source note" do
    assert_equal 2, EntrySearch.new(source: "Sueños p.14").total
  end

  test "filters by an open-ended and a closed date range" do
    assert_equal 1, EntrySearch.new(from: "2026-09-18").total
    # 09-17 (published) and 09-16 (draft), hence status: all.
    assert_equal 2, EntrySearch.new(to: "2026-09-17", status: "all").total
    assert_equal 2, EntrySearch.new(from: "2026-09-17", to: "2026-09-18").total
  end

  test "ignores an unparseable date rather than returning nothing" do
    search = EntrySearch.new(from: "not-a-date")

    assert_nil search.from
    assert_equal EntrySearch.new.total, search.total
  end

  test "status controls whether drafts appear" do
    assert_not_includes EntrySearch.new.entries, entries(:unfinished)
    assert_includes EntrySearch.new(status: "all").entries, entries(:unfinished)
    assert_equal [ entries(:unfinished) ], EntrySearch.new(status: "draft").entries
  end

  test "an unknown status falls back to published" do
    assert_equal "published", EntrySearch.new(status: "nonsense").status
  end

  test "filters combine" do
    assert_equal 1, EntrySearch.new(q: "montanas", source: "Sueños p.14", from: "2026-09-18").total
  end

  test "reports hidden drafts only when they are actually hidden" do
    assert_equal 1, EntrySearch.new.hidden_draft_count
    assert_equal 0, EntrySearch.new(status: "all").hidden_draft_count
  end

  # --- highlights -----------------------------------------------------------

  # The query object emits private-use markers, not markup; SearchHelper turns
  # them into <mark> after escaping the rest. See SearchHelperTest.
  test "wraps the match in highlight markers" do
    snippet = EntrySearch.new(q: "montanas").highlights[entries(:sueno_es).id]

    assert_includes snippet, "#{EntrySearch::HIGHLIGHT_OPEN}montañas#{EntrySearch::HIGHLIGHT_CLOSE}"
  end

  test "the markers are not markup, so an entry cannot smuggle tags out" do
    assert_not_includes EntrySearch::HIGHLIGHT_OPEN, "<"
    assert_not_includes EntrySearch::HIGHLIGHT_CLOSE, "<"
  end

  test "browsing computes no highlights" do
    assert_empty EntrySearch.new.highlights
  end

  test "highlights only the entries on the current page" do
    25.times { |i| Entry.create!(body: "Montañas número #{i}", written_on: Date.current, language: "es") }

    search = EntrySearch.new(q: "montanas")

    assert_operator search.total, :>, EntrySearch::PER_PAGE
    assert_equal search.entries.size, search.highlights.size
    assert_operator search.highlights.size, :<=, EntrySearch::PER_PAGE
  end

  # --- pagination -----------------------------------------------------------

  test "paginates" do
    30.times { |i| Entry.create!(body: "Entrada #{i}", written_on: Date.current - i, language: "es") }

    first = EntrySearch.new
    second = EntrySearch.new(page: 2)

    assert_equal EntrySearch::PER_PAGE, first.entries.size
    assert_equal 2, first.total_pages
    assert_empty first.entries & second.entries
    assert_equal 2, second.page
  end

  test "clamps a page past the end instead of showing an empty list" do
    search = EntrySearch.new(page: 99)

    assert_equal 1, search.page
    assert_equal 1, search.first_on_page
    assert_not_empty search.entries
  end

  test "handles no results without nonsense counters" do
    search = EntrySearch.new(q: "zzzznotaword")

    assert_equal 0, search.total
    assert_equal 0, search.first_on_page
    assert_equal 1, search.total_pages
    assert_empty search.entries
  end

  private
    def results(query) = EntrySearch.new(q: query).entries
end
