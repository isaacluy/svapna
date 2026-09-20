require "test_helper"

class EntryTest < ActiveSupport::TestCase
  test "requires a body and a date" do
    entry = Entry.new

    assert_not entry.valid?
    assert_includes entry.errors.attribute_names, :body
    assert_includes entry.errors.attribute_names, :written_on
  end

  test "rejects a language with no text search configuration" do
    entry = Entry.new(body: "x", written_on: Date.current, language: "klingon")

    assert_not entry.valid?
    assert_includes entry.errors.full_messages.to_sentence, "Language"
  end

  test "digest ignores whitespace and case so reformatting is not a new entry" do
    assert_equal Entry.digest_for("Soñé  con\n\nmontañas"), Entry.digest_for("soñé con montañas")
  end

  test "digest distinguishes genuinely different bodies" do
    assert_not_equal Entry.digest_for("uno"), Entry.digest_for("dos")
  end

  test "assigns the digest on save" do
    entry = Entry.create!(body: "Un sueño corto", written_on: Date.current, language: "es")

    assert_equal Entry.digest_for("Un sueño corto"), entry.body_digest
  end

  test "is identified by its date, not a title" do
    assert_not Entry.column_names.include?("title")
    assert_equal I18n.l(entries(:sueno_es).written_on, format: :long), entries(:sueno_es).to_s
  end

  test "chronological puts newest first and orders same-day entries by position" do
    same_day = Entry.create!(body: "Segundo", written_on: entries(:sueno_es).written_on,
                             position: 1, language: "es")

    ordered = Entry.chronological.to_a

    assert_equal entries(:sueno_es), ordered.first
    assert_equal same_day, ordered.second
  end
end
