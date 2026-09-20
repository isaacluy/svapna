require "test_helper"

class NotesImport::CommitterTest < ActiveSupport::TestCase
  setup { Entry.delete_all }

  test "persists entries and records the counts" do
    import = import_sample

    assert_equal 3, import.entries_count
    assert_equal 0, import.duplicate_count
    assert_equal "Sueños p.14", import.source
    assert_equal 3, import.entries.count
  end

  test "stamps every entry with the note title as its source" do
    import_sample

    assert_equal [ "Sueños p.14" ], Entry.imported.distinct.pluck(:source)
  end

  test "created_at follows the entry's own date, not the clock" do
    import_sample

    entry = Entry.imported.find_by(written_on: Date.new(2026, 9, 17))

    assert_equal Date.new(2026, 9, 17), entry.created_at.to_date
    assert_equal 12, entry.created_at.hour, "midday UTC keeps the date right in any timezone"
  end

  test "tags entries containing the important keyword" do
    import_sample

    important = Entry.tagged_with("important")

    assert_equal 1, important.count
    assert_equal Date.new(2026, 9, 16), important.sole.written_on
  end

  test "re-importing the same file creates nothing" do
    import_sample

    assert_no_difference -> { Entry.count } do
      second = import_sample

      assert_equal 0, second.entries_count
      assert_equal 3, second.duplicate_count
    end
  end

  test "deduplicates entries repeated within a single file" do
    text = "Diario\n———\n2026/09/18\n\nEl mismo texto\n———\n2026/09/18\n\nEl mismo texto"

    import = NotesImport::Runner.import(text)

    assert_equal 1, import.entries_count
    assert_equal 1, import.duplicate_count
  end

  test "reformatting is not treated as a new entry" do
    NotesImport::Runner.import("Diario\n———\n2026/09/18\n\nSoñé con montañas")
    second = NotesImport::Runner.import("Diario\n———\n2026/09/18\n\nSoñé   con\nmontañas")

    assert_equal 0, second.entries_count, "whitespace-only differences are the same entry"
  end

  test "keeps a record of skipped sections" do
    import = NotesImport::Runner.import("Diario\n———\nsin fecha\n\nCuerpo\n———\n2026/09/18\n\nBueno")

    assert_equal 1, import.entries_count
    assert_equal 1, import.skipped_count
    assert_match(/Expected a date/, import.parse_errors.sole["reason"])
  end

  test "undoing an import deletes its entries and their taggings" do
    import = import_sample

    assert_difference -> { Tagging.count }, -1 do
      assert_difference -> { Entry.count }, -3 do
        import.destroy!
      end
    end

    # The tag vocabulary survives: it is shared, not owned by an import.
    assert Tag.exists?(name: "important")
  end

  test "undoing one import leaves the others alone" do
    first = NotesImport::Runner.import("A\n———\n2026/09/18\n\nUno")
    NotesImport::Runner.import("B\n———\n2026/09/17\n\nDos")

    first.destroy!

    assert_equal 1, Entry.count
    assert_equal "Dos", Entry.sole.body
  end

  test "an entry written in the app is untouched by import dedupe" do
    written_here = Entry.create!(body: "Uno", written_on: Date.new(2026, 9, 18), language: "es")

    NotesImport::Runner.import("A\n———\n2026/09/18\n\nUno")

    assert_equal 2, Entry.count, "the imported copy is separate from the one written here"
    assert_nil written_here.reload.import_id
  end

  private
    def import_sample
      NotesImport::Runner.import(file_fixture("suenos_p14.txt").read, filename: "suenos_p14.txt")
    end
end
