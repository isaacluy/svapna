require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "normalises case and surrounding space" do
    assert_equal "pesadilla", Tag.normalize("  Pesadilla  ")
    assert_equal "sueño lúcido", Tag.normalize("Sueño Lúcido")
  end

  test "stores the normalised name" do
    assert_equal "volar", Tag.create!(name: " VOLAR ").name
  end

  test "find_or_create_by_name! is idempotent across spellings" do
    first = Tag.find_or_create_by_name!("Volar")

    assert_no_difference -> { Tag.count } do
      assert_equal first, Tag.find_or_create_by_name!("  volar ")
    end
  end

  test "in_use excludes a tag with no entries" do
    orphan = Tag.create!(name: "huérfana")
    entries(:sueno_es).tag!("usada")

    assert_includes Tag.in_use, Tag.find_by(name: "usada")
    assert_not_includes Tag.in_use, orphan
  end
end
