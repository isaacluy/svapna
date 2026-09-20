require "test_helper"

class EntriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "requires authentication" do
    sign_out

    get entries_path

    assert_redirected_to new_session_path
  end

  test "index lists entries newest first" do
    get entries_path

    assert_response :success
    assert_select "li", minimum: 3
  end

  test "show renders the body with paragraphs preserved" do
    get entry_path(entries(:sueno_es))

    assert_response :success
    assert_select "p", text: /Soñé con montañas/
    assert_select "p", text: /Soñaba mucho/
  end

  test "creates an entry" do
    assert_difference -> { Entry.count }, 1 do
      post entries_path, params: { entry: {
        body: "Una entrada nueva", written_on: "2026-09-19", language: "es", status: "draft"
      } }
    end

    assert_redirected_to entry_path(Entry.order(:created_at).last)
    assert_equal "Una entrada nueva", Entry.order(:created_at).last.body
  end

  test "rejects an invalid entry without creating it" do
    assert_no_difference -> { Entry.count } do
      post entries_path, params: { entry: { body: "", written_on: "2026-09-19", language: "es" } }
    end

    assert_response :unprocessable_entity
  end

  test "updates an entry and recomputes its search vector" do
    entry = entries(:sueno_es)
    before = entry.search_vector

    patch entry_path(entry), params: { entry: { body: "Texto sobre bicicletas" } }

    assert_redirected_to entry_path(entry)
    assert_not_equal before, entry.reload.search_vector
  end

  test "destroys an entry" do
    assert_difference -> { Entry.count }, -1 do
      delete entry_path(entries(:unfinished))
    end

    assert_redirected_to entries_path
  end

  test "new and edit render the form" do
    get new_entry_path
    assert_response :success

    get edit_entry_path(entries(:sueno_es))
    assert_response :success
    assert_select "textarea"
  end
end
