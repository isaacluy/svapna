require "test_helper"

class SearchHelperTest < ActionView::TestCase
  include SearchHelper

  OPEN = EntrySearch::HIGHLIGHT_OPEN
  CLOSE = EntrySearch::HIGHLIGHT_CLOSE

  test "turns the markers into mark tags" do
    assert_equal "Soñé con <mark>montañas</mark>",
                 highlighted("Soñé con #{OPEN}montañas#{CLOSE}")
  end

  test "escapes markup in the entry rather than stripping it" do
    result = highlighted("#{OPEN}Uno#{CLOSE} <script>alert('x')</script> dos")

    assert_includes result, "<mark>Uno</mark>"
    assert_includes result, "&lt;script&gt;", "the tag should survive as visible text"
    assert_not_includes result, "<script>"
  end

  test "escapes an attribute-style injection" do
    result = highlighted(%{#{OPEN}a#{CLOSE} <img src=x onerror="alert(1)">})

    assert_not_includes result, "<img"
    assert_includes result, "&lt;img"
  end

  test "renders the fragment delimiter as a separator" do
    result = highlighted("uno#{EntrySearch::FRAGMENT_DELIMITER}dos")

    assert_includes result, "&hellip;"
    assert_no_match(/#{EntrySearch::FRAGMENT_DELIMITER}/, result)
  end

  test "is marked html safe so the marks render" do
    assert_predicate highlighted("#{OPEN}x#{CLOSE}"), :html_safe?
  end

  test "handles a nil snippet" do
    assert_equal "", highlighted(nil)
  end
end
