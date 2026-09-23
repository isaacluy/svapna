require "test_helper"

class InsightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    Entry.delete_all
    Entry.create!(body: "El mar y las montañas. El mar otra vez. Siempre el mar.",
                  written_on: Date.new(2026, 9, 18), language: "es", source: "Sueños p.1")
    Entry.create!(body: "Las montañas eran altas.",
                  written_on: Date.new(2026, 9, 17), language: "es", source: "Sueños p.2")
  end

  test "requires authentication" do
    sign_out

    get insights_path

    assert_redirected_to new_session_path
  end

  test "shows the most repeated word and the counts" do
    get insights_path

    assert_response :success
    assert_select "dd", text: "mar"
    assert_select "th[scope=row]", text: "mar"
  end

  test "excludes common words by default and says how many" do
    get insights_path

    assert_select "th[scope=row]", { text: "el", count: 0 }
    assert_select "p", /common word.? excluded/
  end

  test "common words can be included" do
    get insights_path(stopwords: "none")

    assert_select "th[scope=row]", text: "el"
  end

  test "answers the question for a subset of entries" do
    get insights_path(source: "Sueños p.2")

    assert_select "dd", text: "1"                       # one entry selected
    assert_select "th[scope=row]", text: "altas"
    assert_select "th[scope=row]", { text: "mar", count: 0 }
  end

  test "the same filters as the entry list apply" do
    get insights_path(q: "altas")

    assert_select "th[scope=row]", text: "altas"
    assert_select "th[scope=row]", { text: "mar", count: 0 }
  end

  test "a date range narrows the selection" do
    get insights_path(from: "2026-09-18")

    assert_select "th[scope=row]", text: "mar"
    assert_select "th[scope=row]", { text: "altas", count: 0 }
  end

  test "the limit is respected" do
    get insights_path(limit: 2)

    assert_select "tbody tr", 2
  end

  test "the entry list links through carrying its filters" do
    get entries_path(q: "montanas", status: "all")

    assert_select "a[href*=?]", "insights"
    assert_select "a[href*=?]", "q=montanas"
  end

  test "a word links back to a search for it" do
    get insights_path

    assert_select "a[href=?]", entries_path(q: "mar")
  end

  test "says so when the filters select nothing" do
    get insights_path(q: "zzzznotaword")

    assert_select "p", /Nothing selected/
  end

  test "bars are drawn for a single series, not coloured per rank" do
    get insights_path

    # One fill class for every bar: colour follows the measure, never the rank.
    assert_select "span.meter-fill", minimum: 2
    assert_select "[class*=meter-fill][style*='background']", 0,
      "no per-row colour override"
  end

  test "every bar carries its value as text" do
    get insights_path

    assert_select "tbody tr" do
      assert_select "span.meter-value", minimum: 1
    end
  end

  test "the table is readable without the bars" do
    get insights_path

    assert_select "table caption"
    assert_select "thead th[scope=col]", 3
  end
end
