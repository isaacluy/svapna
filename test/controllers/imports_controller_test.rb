require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    Entry.delete_all
  end

  test "requires authentication" do
    sign_out

    get new_import_path

    assert_redirected_to new_session_path
  end

  test "imports pasted text" do
    assert_difference -> { Entry.count }, 3 do
      post imports_path, params: { import: { text: file_fixture("suenos_p14.txt").read } }
    end

    assert_redirected_to Import.last
    follow_redirect!
    assert_select "h1", /Sueños p\.14/
  end

  test "imports an uploaded file" do
    assert_difference -> { Entry.count }, 3 do
      post imports_path, params: { import: { files: [ uploaded_sample ] } }
    end

    assert_equal "suenos_p14.txt", Import.last.filename
  end

  test "gives each uploaded file its own import so they can be undone separately" do
    assert_difference -> { Import.count }, 2 do
      post imports_path, params: { import: { files: [ uploaded_sample, uploaded("B\n———\n2026/01/01\n\nOtro", "b.txt") ] } }
    end

    assert_redirected_to imports_path
  end

  test "rejects an empty submission" do
    assert_no_difference -> { Import.count } do
      post imports_path, params: { import: { text: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "reports duplicates on a second import rather than failing" do
    post imports_path, params: { import: { text: file_fixture("suenos_p14.txt").read } }

    assert_no_difference -> { Entry.count } do
      post imports_path, params: { import: { text: file_fixture("suenos_p14.txt").read } }
    end

    assert_match(/already present/, flash[:notice])
  end

  test "shows skipped sections instead of hiding them" do
    post imports_path, params: { import: { text: "Diario\n———\nsin fecha\n\nCuerpo" } }
    follow_redirect!

    assert_select "h2", /1 section skipped/
    assert_match(/Expected a date/, response.body)
  end

  test "warns when nothing was imported" do
    post imports_path, params: { import: { text: "No dividers here at all" } }
    follow_redirect!

    assert_match(/divider lines were\s+not recognised/, response.body)
  end

  test "undo deletes the entries the import created" do
    post imports_path, params: { import: { text: file_fixture("suenos_p14.txt").read } }
    import = Import.last

    assert_difference -> { Entry.count }, -3 do
      delete import_path(import)
    end

    assert_redirected_to imports_path
  end

  test "index lists imports" do
    post imports_path, params: { import: { text: file_fixture("suenos_p14.txt").read } }

    get imports_path

    assert_response :success
    assert_select "li", minimum: 1
  end

  private
    def uploaded_sample
      uploaded(file_fixture("suenos_p14.txt").read, "suenos_p14.txt")
    end

    def uploaded(content, name)
      file = Tempfile.new([ name, ".txt" ]).tap { |f| f.write(content); f.rewind }
      Rack::Test::UploadedFile.new(file.path, "text/plain", original_filename: name)
    end
end
