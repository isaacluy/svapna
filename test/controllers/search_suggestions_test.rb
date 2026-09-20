require "test_helper"

class SearchSuggestionsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "offers a correction when a search finds nothing" do
    get entries_path(q: "montanhas")

    assert_select "p", /Did you mean/
    assert_select "a", text: "montañas"
  end

  test "the suggestion links to a search for that word" do
    get entries_path(q: "montanhas")

    assert_select "a[href=?]", entries_path(q: "montañas")
  end

  test "no suggestion when the search found something" do
    get entries_path(q: "montanas")

    assert_select "p", { text: /Did you mean/, count: 0 }
  end

  test "no suggestion when nothing is close enough" do
    get entries_path(q: "xyzzy")

    assert_select "p", /No entries match/
    assert_select "p", { text: /Did you mean/, count: 0 }
  end

  test "no suggestion for a multi-word query" do
    # Correcting one word of a phrase means guessing which was wrong.
    get entries_path(q: "montanhas altas")

    assert_select "p", { text: /Did you mean/, count: 0 }
  end

  test "suggestions survive alongside the other filters" do
    get entries_path(q: "montanhas", status: "all")

    assert_select "a[href*=?]", "status=all"
  end
end
