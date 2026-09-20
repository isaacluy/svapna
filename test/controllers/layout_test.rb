require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "signed-out pages have no navigation" do
    get new_session_path

    assert_response :success
    assert_select "header", false, "the header should be hidden before sign-in"
  end

  test "signed-in pages carry the navigation" do
    sign_in_as users(:one)

    get root_path

    assert_select "header nav a", text: "Entries"
    assert_select "header nav a", text: "Imports"
  end

  test "the entry page renders each paragraph separately in the reading style" do
    sign_in_as users(:one)

    get entry_path(entries(:sueno_es))

    assert_select ".prose-entry p", 2, "the fixture has two paragraphs"
  end

  test "pages declare a title" do
    sign_in_as users(:one)

    get entries_path

    assert_select "title", /Entries/
  end

  test "the viewport is set up for phones and notched screens" do
    get new_session_path

    assert_select "meta[name=viewport][content*='viewport-fit=cover']", 1
  end

  test "a theme colour is declared for both schemes" do
    get new_session_path

    assert_select "meta[name=theme-color][media*='light']", 1
    assert_select "meta[name=theme-color][media*='dark']", 1
  end
end
