require "test_helper"

class EntryTaggingTest < ActiveSupport::TestCase
  test "assigns tags from a comma-separated list" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es",
                          tag_list: "Pesadilla, VOLAR")

    assert_equal %w[pesadilla volar], entry.reload.tags.pluck(:name).sort
  end

  test "ignores blanks and duplicates" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es",
                          tag_list: "volar, , volar,   ,Volar")

    assert_equal %w[volar], entry.reload.tags.pluck(:name)
  end

  test "removes tags left out of a later list" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es",
                          tag_list: "pesadilla, volar")

    entry.update!(tag_list: "volar")

    assert_equal %w[volar], entry.reload.tags.pluck(:name)
  end

  test "an empty list clears every tag" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es", tag_list: "volar")

    entry.update!(tag_list: "")

    assert_empty entry.reload.tags
  end

  test "reuses an existing tag rather than duplicating it" do
    entries(:sueno_es).tag!("volar")

    assert_no_difference -> { Tag.count } do
      Entry.create!(body: "Otro", written_on: Date.current, language: "es", tag_list: "Volar")
    end
  end

  test "tag_list reads back sorted" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es",
                          tag_list: "volar, important, pesadilla")

    assert_equal "important, pesadilla, volar", entry.reload.tag_list
  end

  test "leaving tag_list untouched does not disturb existing tags" do
    entry = entries(:sueno_es)
    entry.tag!("volar")

    entry.update!(body: "Texto distinto")

    assert_equal %w[volar], entry.reload.tags.pluck(:name)
  end

  test "destroying an entry removes its taggings but keeps the vocabulary" do
    entry = Entry.create!(body: "Uno", written_on: Date.current, language: "es", tag_list: "volar")

    assert_difference -> { Tagging.count }, -1 do
      entry.destroy!
    end

    assert Tag.exists?(name: "volar"), "the tag survives for reuse; bin/d r tags:prune clears it"
  end
end
