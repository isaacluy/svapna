require "test_helper"

class NotesImport::ParserTest < ActiveSupport::TestCase
  test "parses the real sample note" do
    result = parse(file_fixture("suenos_p14.txt").read)

    assert_equal "Sueños p.14", result.source
    assert_equal 3, result.entries.size
    assert_empty result.skipped
    assert_equal [ Date.new(2026, 9, 18), Date.new(2026, 9, 17), Date.new(2026, 9, 16) ],
                 result.entries.map(&:written_on)
  end

  test "the note title labels every entry and is never an entry title" do
    result = parse("Sueños p.14\n———\n2026/09/18\n\nCuerpo")

    assert_equal "Sueños p.14", result.source
    assert_equal "Cuerpo", result.entries.sole.body
  end

  test "position follows file order so same-day entries keep their sequence" do
    result = parse("Diario\n———\n2026/09/18\n\nPrimero\n———\n2026/09/18\n\nSegundo")

    assert_equal [ 0, 1 ], result.entries.map(&:position)
    assert_equal %w[Primero Segundo], result.entries.map(&:body)
  end

  test "accepts hyphen, en dash and em dash dividers" do
    [ "---", "———", "–––", "-----" ].each do |divider|
      result = parse("Título\n#{divider}\n2026/09/18\n\nCuerpo")

      assert_equal 1, result.entries.size, "#{divider.inspect} should be a divider"
    end
  end

  test "accepts slash, dash and dot date separators" do
    [ "2026/09/18", "2026-09-18", "2026.09.18" ].each do |date|
      result = parse("Título\n———\n#{date}\n\nCuerpo")

      assert_equal Date.new(2026, 9, 18), result.entries.sole.written_on, date
    end
  end

  test "preserves paragraph breaks but trims ragged blank lines" do
    result = parse("Título\n———\n2026/09/18\n\n\n\nUno\n\n\n\nDos\n\n\n")

    assert_equal "Uno\n\nDos", result.entries.sole.body
  end

  test "survives CRLF line endings" do
    result = parse("Título\r\n———\r\n2026/09/18\r\n\r\nCuerpo\r\n")

    assert_equal 1, result.entries.size
    assert_equal "Cuerpo", result.entries.sole.body
  end

  test "survives non-breaking spaces around a divider" do
    # Apple Notes emits these, and left alone they stop the divider matching,
    # silently merging two entries into one.
    result = parse("Título\n ——— \n2026/09/18\n\nCuerpo")

    assert_equal 1, result.entries.size
  end

  test "records a dateless section instead of dropping it" do
    result = parse("Título\n———\nNo hay fecha\n\nCuerpo\n———\n2026/09/18\n\nBueno")

    assert_equal 1, result.entries.size
    assert_equal 1, result.skipped.size
    assert_match(/Expected a date/, result.skipped.sole.reason)
    assert_match(/No hay fecha/, result.skipped.sole.preview)
  end

  test "records an impossible date instead of raising" do
    result = parse("Título\n———\n2026/13/45\n\nCuerpo")

    assert_empty result.entries
    assert_match(/not a real date/, result.skipped.sole.reason)
  end

  test "records a dated section with no body" do
    result = parse("Título\n———\n2026/09/18\n\n   \n")

    assert_empty result.entries
    assert_match(/no body/, result.skipped.sole.reason)
  end

  test "one bad section does not abort the rest of the file" do
    result = parse("Diario\n———\nsin fecha\n\nMalo\n———\n2026/09/17\n\nBueno\n———\n2026/13/99\n\nPeor\n———\n2026/09/16\n\nTambién bueno")

    assert_equal 2, result.entries.size
    assert_equal %w[Bueno], result.entries.map(&:body).first(1)
    assert_equal 2, result.skipped.size
  end

  test "reports a file with no dividers rather than returning nothing" do
    result = parse("Just some text with no dividers at all")

    assert_empty result.entries
    assert_match(/No divider/, result.skipped.sole.reason)
  end

  test "handles an empty file" do
    result = parse("")

    assert_nil result.source
    assert_empty result.entries
    assert_equal 1, result.skipped.size
  end

  test "digest matches the model so the importer and the index agree" do
    result = parse("Título\n———\n2026/09/18\n\nSoñé con montañas")

    assert_equal Entry.digest_for("Soñé con montañas"), result.entries.sole.digest
  end

  private
    def parse(text) = NotesImport::Parser.new(text).call
end
