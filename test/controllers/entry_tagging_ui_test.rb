require "test_helper"

class EntryTaggingUiTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the form carries a tag field prefilled with the current tags" do
    entries(:sueno_es).tag!("volar")

    get edit_entry_path(entries(:sueno_es))

    assert_select "input[name='entry[tag_list]'][value=?]", "volar"
  end

  test "existing tags are offered as suggestions" do
    entries(:sueno_es).tag!("volar")

    get new_entry_path

    assert_select "datalist#known-tags option[value=?]", "volar"
  end

  test "tags can be set when creating an entry" do
    post entries_path, params: { entry: {
      body: "Volé sobre el mar", written_on: "2026-09-19", language: "es",
      status: "published", tag_list: "Volar, pesadilla"
    } }

    assert_equal %w[pesadilla volar], Entry.order(:created_at).last.tags.pluck(:name).sort
  end

  test "tags can be changed when editing" do
    entry = entries(:sueno_es)
    entry.tag!("volar")

    patch entry_path(entry), params: { entry: { tag_list: "pesadilla" } }

    assert_equal %w[pesadilla], entry.reload.tags.pluck(:name)
  end

  test "a tag on the entry page links to the filtered list" do
    entries(:sueno_es).tag!("volar")

    get entry_path(entries(:sueno_es))

    assert_select "a[href=?]", entries_path(tag: "volar")
  end

  test "the important tag is styled distinctly" do
    entries(:sueno_es).tag!("important")

    get entry_path(entries(:sueno_es))

    assert_select "span.tag.tag-marker", text: "important"
  end
end
