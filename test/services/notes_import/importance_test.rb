require "test_helper"

class NotesImport::ImportanceTest < ActiveSupport::TestCase
  test "matches the sample's parenthesised marker" do
    assert NotesImport::Importance.important?("... aute dolor consequat. ( important ? )")
  end

  test "matches Spanish, Portuguese and Italian forms" do
    assert NotesImport::Importance.important?("Esto es importante")
    assert NotesImport::Importance.important?("Son importantes")
  end

  test "ignores case and accents" do
    assert NotesImport::Importance.important?("IMPORTANTE")
    assert NotesImport::Importance.important?("Impórtante")
  end

  test "matches whole words only" do
    assert_not NotesImport::Importance.important?("self-importantly unimportant"),
      "'importantly' and 'unimportant' should not count"
    assert_not NotesImport::Importance.important?("importancia")
  end

  test "is false for ordinary text" do
    assert_not NotesImport::Importance.important?("Soñé con montañas")
  end
end
