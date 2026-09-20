require "test_helper"

class EntrySearchUiTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "searching narrows the list and highlights the match" do
    get entries_path(q: "montanas")

    assert_response :success
    assert_select "mark", text: "montañas"
    assert_select "li", 1
  end

  test "the summary describes what was searched" do
    get entries_path(q: "montanas")

    assert_select "p", /1 entry matching/
  end

  # ts_headline does not escape the document it is given, so a body containing
  # markup would otherwise be injected straight into the page.
  test "a snippet cannot inject markup" do
    # Adjacent to the match on purpose: ts_headline only returns a fragment
    # around the hit, so markup further away would be cropped out and the test
    # would pass without sanitising anything.
    Entry.create!(body: "Vi montañas <script>alert('xss')</script> muy peligrosas en el valle",
                  written_on: Date.current, language: "es")

    get entries_path(q: "montanas")

    assert_response :success
    assert_no_match(%r{<script>alert}, response.body)
    assert_select "mark", minimum: 1
    # Postgres' text search parser recognises HTML tags as tokens and drops
    # them from the headline, so the tags never even reach Ruby. The helper
    # escapes anyway -- see SearchHelperTest.
  end

  test "filters survive in the pagination links" do
    30.times do |i|
      Entry.create!(body: "Montañas #{i}", written_on: Date.current - i,
                    language: "es", source: "Sueños p.14")
    end

    get entries_path(q: "montanas", source: "Sueños p.14", status: "all")

    assert_select "nav[aria-label=Pagination] a" do |links|
      assert links.any? { |a| a["href"].include?("q=montanas") }, "query should survive"
      assert links.any? { |a| a["href"].include?("status=all") }, "filters should survive"
    end
  end

  test "an empty result set explains the search syntax" do
    get entries_path(q: "zzzznotaword")

    assert_select "p", /No entries match/
    assert_match(/Quotes search a phrase/, response.body)
  end

  test "malformed input does not blow up the page" do
    get entries_path(q: %q("unclosed AND - or))

    assert_response :success
  end

  test "the header carries a search box" do
    get root_path

    assert_select "header form input[type=search][name=q]", 1
  end

  test "filters are open when in use and the tag facet is offered" do
    entries(:sueno_es).tag!("important")

    get entries_path(tag: "important")

    assert_select "details[open]", 1
    assert_select "select[name=tag] option[value=important]"
    assert_select "li", 1
  end

  test "search requires authentication" do
    sign_out

    get entries_path(q: "montanas")

    assert_redirected_to new_session_path
  end
end
