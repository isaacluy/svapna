# The distinct words actually written in the journal, used to suggest a
# correction when a search finds nothing.
#
# Computed on demand rather than kept in a table: it is only ever reached after
# a search returns zero results, which is rare, and a stored copy would add
# staleness and a refresh step to forget. If the corpus grows enough for this
# to drag, materialise it then.
module Vocabulary
  # Postgres' default trigram threshold is 0.3; a little higher keeps the
  # suggestions from being noise.
  SIMILARITY_THRESHOLD = 0.35

  # word_vector is unstemmed and keeps accents, so suggestions read as real
  # words -- "sueños", not the stem "sueñ".
  SOURCE = "SELECT word_vector FROM entries WHERE status = 'published'".freeze

  SIMILAR_SQL = <<~SQL.freeze
    SELECT word
    FROM ts_stat(?)
    WHERE word <> ? AND similarity(word, ?) >= ?
    ORDER BY similarity(word, ?) DESC, nentry DESC, word
    LIMIT ?
  SQL

  module_function

  def similar_to(word, limit: 3)
    normalized = word.to_s.strip.downcase
    return [] if normalized.blank?

    Entry.connection.select_values(
      Entry.sanitize_sql_array([
        SIMILAR_SQL, SOURCE, normalized, normalized, SIMILARITY_THRESHOLD, normalized, limit
      ])
    )
  end
end
