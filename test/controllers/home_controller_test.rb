require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to sign in when unauthenticated" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "renders when authenticated" do
    sign_in_as users(:one)

    get root_path

    assert_response :success
    assert_select "h1", "Svapna"
  end

  test "returns to the originally requested page after signing in" do
    get root_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to root_url
  end

  # Coolify's health check is unauthenticated, so this must never be gated.
  test "health check is public" do
    get rails_health_check_path

    assert_response :success
  end
end
