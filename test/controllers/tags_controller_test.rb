require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "requires authentication" do
    sign_out

    get tags_path

    assert_redirected_to new_session_path
  end

  test "lists tags in use with their counts, most used first" do
    entries(:sueno_es).tag!("volar")
    entries(:dream_en).tag!("volar")
    entries(:sueno_es).tag!("pesadilla")

    get tags_path

    assert_response :success
    assert_select "li a", 2
    assert_select "li:first-child", /volar/, "the most used tag comes first"
  end

  test "a tag links to the filtered entry list" do
    entries(:sueno_es).tag!("volar")

    get tags_path

    assert_select "a[href=?]", entries_path(tag: "volar")
  end

  test "separates tags that are no longer in use" do
    Tag.create!(name: "huérfana")

    get tags_path

    assert_select "h2", /Not in use/
    assert_match(/huérfana/, response.body)
  end

  test "says so when there are no tags at all" do
    get tags_path

    assert_select "p", /No tags yet/
  end

  test "the header links to tags" do
    get root_path

    assert_select "header nav a[href=?]", tags_path
  end
end
