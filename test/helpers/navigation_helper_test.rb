require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  include NavigationHelper

  test "marks the current section, including its nested pages" do
    with_path "/entries/9" do
      assert_match 'aria-current="page"', nav_link_to("Entries", "/entries")
    end
  end

  test "does not mark a different section" do
    with_path "/entries" do
      assert_no_match 'aria-current="page"', nav_link_to("Imports", "/imports")
    end
  end

  test "root only matches itself, not every path beneath it" do
    with_path "/entries" do
      assert_no_match 'aria-current="page"', nav_link_to("Home", "/")
    end
  end

  private
    def with_path(path)
      @request = ActionDispatch::TestRequest.create.tap { |r| r.path_info = path }
      yield
    end

    def request = @request
end
