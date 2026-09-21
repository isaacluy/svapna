require "application_system_test_case"

# The one part of the composer only a browser can prove: the Stimulus controller
# really does save as you type.
class AutosaveTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    # click_on does not wait for the navigation it triggers, so without this the
    # next `visit` races the sign-in POST and lands back on the login page.
    assert_text "Sign out"
  end

  test "a new entry saves itself while you write" do
    visit new_entry_path

    assert_text "Not saved yet"

    assert_difference -> { Entry.count }, 1 do
      fill_in "Entry", with: "Anoche soñé con un río muy ancho"
      assert_text(/Saved \d/, wait: 15)
    end

    entry = Entry.order(:created_at).last

    assert_equal "Anoche soñé con un río muy ancho", entry.body
    assert_predicate entry, :draft?
  end

  test "later keystrokes update the same entry instead of creating another" do
    visit new_entry_path
    fill_in "Entry", with: "Primera versión"
    assert_text(/Saved \d/, wait: 15)

    entry = Entry.order(:created_at).last

    fill_in "Entry", with: "Segunda versión, más larga"
    assert_text(/Saved \d/, wait: 15)

    assert_equal "Segunda versión, más larga", entry.reload.body
    assert_equal 1, Entry.where(body: [ "Primera versión", "Segunda versión, más larga" ]).count
  end

  test "the address bar moves to the entry once it exists" do
    visit new_entry_path
    fill_in "Entry", with: "Con identificador"
    assert_text(/Saved \d/, wait: 15)

    assert_current_path edit_entry_path(Entry.order(:created_at).last)
  end

  test "publish becomes usable after the first save" do
    visit new_entry_path
    fill_in "Entry", with: "Listo para publicar"
    assert_text(/Saved \d/, wait: 15)

    click_on "Publish"

    # Wait for the redirect before reading the database, or the assertion races
    # the request.
    assert_text "Entry published."
    assert_predicate Entry.order(:created_at).last.reload, :published?
  end

  test "an empty body is not autosaved, so no blank draft is created" do
    visit new_entry_path

    assert_no_difference -> { Entry.count } do
      fill_in "Entry", with: "   "
      sleep 4
    end

    assert_no_text(/Saved \d/)
  end

  test "editing an existing draft autosaves in place" do
    draft = entries(:unfinished)
    visit edit_entry_path(draft)

    fill_in "Entry", with: "Continuando el borrador"

    assert_text(/Saved \d/, wait: 15)
    assert_equal "Continuando el borrador", draft.reload.body
  end
end
