require "test_helper"

class ComposerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  # --- the surface, without JavaScript ---------------------------------------

  test "the composer works as a plain form: it has a real submit button" do
    get new_entry_path

    assert_response :success
    assert_select "form input[type=submit]", 1
  end

  test "a new entry defaults to a draft dated today" do
    get new_entry_path

    assert_select "input[name='entry[written_on]'][value=?]", Date.current.to_s
    assert_select "select[name='entry[status]'] option[value=draft][selected]"
  end

  test "saving without JavaScript creates the entry" do
    assert_difference -> { Entry.count }, 1 do
      post entries_path, params: { entry: {
        body: "Escrito a mano", written_on: Date.current.to_s, language: "es", status: "draft"
      } }
    end

    assert_equal "Escrito a mano", Entry.order(:created_at).last.body
  end

  test "the autosave controller is attached with its targets" do
    get new_entry_path

    assert_select "[data-controller=autosave]"
    assert_select "[data-autosave-target=form]"
    assert_select "[data-autosave-target=status]"
    assert_select "textarea[data-autosave-target=body]"
  end

  # Stimulus only sees targets inside its own element. Publish has to be its own
  # form (different action and verb), so it sits outside the entry form -- which
  # is why the controller is on a wrapper. Getting this wrong makes autosave look
  # fine while Publish silently never activates.
  test "every autosave target is inside the controller element" do
    get new_entry_path

    assert_select "[data-controller=autosave]" do
      assert_select "[data-autosave-target=form]", 1
      assert_select "[data-autosave-target=publish]", 1
      assert_select "[data-autosave-target=status]", 1
      assert_select "[data-autosave-target=body]", 1
    end
  end

  test "the publish button is its own form, not nested in the entry form" do
    get edit_entry_path(entries(:unfinished))

    assert_select "form[data-autosave-target=form] form", 0, "nested forms are invalid HTML"
  end

  test "publish is hidden and disabled until the entry exists" do
    get new_entry_path

    assert_select "[data-autosave-target=publish][hidden]"
    assert_select "[data-autosave-target=publish] button[disabled]"
  end

  # --- autosave endpoint -----------------------------------------------------

  test "autosaving a new entry creates it and says where to save next" do
    assert_difference -> { Entry.count }, 1 do
      post entries_path, as: :json, params: { entry: {
        body: "Borrador", written_on: Date.current.to_s, language: "es", status: "draft"
      } }
    end

    assert_response :created
    entry = Entry.order(:created_at).last
    body = response.parsed_body

    assert_equal entry.id, body["id"]
    assert_equal entry_path(entry), body["update_url"]
    assert_equal edit_entry_path(entry), body["edit_url"]
    assert_equal publish_entry_path(entry), body["publish_url"]
    assert_equal 1, body["words"]
    assert body["saved_at"].present?
  end

  test "autosaving an existing entry updates it in place" do
    entry = entries(:unfinished)

    assert_no_difference -> { Entry.count } do
      patch entry_path(entry), as: :json, params: { entry: { body: "Más texto ahora" } }
    end

    assert_response :success
    assert_equal "Más texto ahora", entry.reload.body
    assert_equal entry_path(entry), response.parsed_body["update_url"]
  end

  test "autosave reports validation errors instead of failing silently" do
    patch entry_path(entries(:unfinished)), as: :json, params: { entry: { body: "" } }

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"].join, "Body"
  end

  test "autosave recomputes the search vector" do
    entry = entries(:sueno_es)
    before = entry.search_vector

    patch entry_path(entry), as: :json, params: { entry: { body: "Bicicletas por la ciudad" } }

    assert_not_equal before, entry.reload.search_vector
  end

  test "autosave requires authentication" do
    sign_out

    patch entry_path(entries(:unfinished)), as: :json, params: { entry: { body: "x" } }

    assert_response :redirect
  end

  # --- publishing ------------------------------------------------------------

  test "publishing a draft makes it searchable" do
    draft = entries(:unfinished)

    assert_not_includes EntrySearch.new.entries, draft

    patch publish_entry_path(draft)

    assert_redirected_to draft
    assert_predicate draft.reload, :published?
    assert_includes EntrySearch.new.entries, draft
  end

  test "the reading view offers publish only for a draft" do
    get entry_path(entries(:unfinished))
    assert_select "form[action=?]", publish_entry_path(entries(:unfinished))

    get entry_path(entries(:sueno_es))
    assert_select "form[action='#{publish_entry_path(entries(:sueno_es))}']", count: 0
  end

  # --- drafts ----------------------------------------------------------------

  test "the drafts list shows only drafts" do
    get drafts_entries_path

    assert_response :success
    assert_select "li", 1
    assert_select "p", /1 entry.*drafts only/
  end

  test "the home page offers drafts to continue" do
    get root_path

    assert_select "h2", /Continue writing/
    assert_select "a[href=?]", edit_entry_path(entries(:unfinished))
  end

  test "the home page counts only published entries" do
    get root_path

    assert_select "p", /2 entries/
  end

  test "the entry list links hidden drafts to the drafts page" do
    get entries_path

    assert_select "a[href=?]", drafts_entries_path
  end
end
