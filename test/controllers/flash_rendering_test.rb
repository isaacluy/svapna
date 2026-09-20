require "test_helper"

# The layout renders flash messages for every page. Any view that also renders
# its own shows each message twice -- easy to reintroduce, and invisible to a
# `assert_select "div", /text/` style assertion.
class FlashRenderingTest < ActionDispatch::IntegrationTest
  test "a failed sign-in shows its alert exactly once" do
    post session_path, params: { email_address: users(:one).email_address, password: "wrong" }
    follow_redirect!

    assert_equal 1, flash_nodes.size
  end

  test "requesting a password reset shows its notice exactly once" do
    post passwords_path, params: { email_address: users(:one).email_address }
    follow_redirect!

    assert_equal 1, flash_nodes.size
  end

  test "an invalid reset token shows its alert exactly once" do
    get edit_password_path("not-a-real-token")
    follow_redirect!

    assert_equal 1, flash_nodes.size
  end

  test "a signed-in page shows its notice exactly once" do
    sign_in_as users(:one)

    delete entry_path(entries(:unfinished))
    follow_redirect!

    assert_equal 1, flash_nodes.size
  end

  test "no flash renders nothing" do
    get new_session_path

    assert_empty flash_nodes
  end

  private
    def flash_nodes = css_select("[role=status]")
end
