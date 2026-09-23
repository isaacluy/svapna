module Analytics
  # How often each word appears across a set of entries.
  #
  #   Analytics::WordFrequency.call                                  # everything
  #   Analytics::WordFrequency.call(scope: Entry.where(id: ids))     # just these
  #   Analytics::WordFrequency.call(stopwords: :none, limit: 200)
  #
  # One code path for both questions -- "these five entries" and "all of them"
  # differ only by a WHERE clause -- so the two can never disagree.
  class WordFrequency
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 500

    Row = Struct.new(:word, :entries, :occurrences, keyword_init: true) do
      def to_s = word
    end

    attr_reader :limit, :min_length

    def self.call(...) = new(...).call

    # stopwords: :auto  -> the lists for the languages actually in the scope
    #            :none  -> keep everything
    #            [:es]  -> those lists
    def initialize(scope: Entry.published, stopwords: :auto, limit: DEFAULT_LIMIT, min_length: 1)
      @scope = scope
      @stopwords = stopwords
      @limit = limit.to_i.clamp(1, MAX_LIMIT)
      @min_length = min_length.to_i.clamp(1, 40)
    end

    def call = self

    def rows
      @rows ||= cached { query }
    end

    def languages = @languages ||= @scope.distinct.pluck(:language).compact.sort

    def stopword_list
      @stopword_list ||= case @stopwords
      when :none then Set.new
      when :auto then Stopwords.for(languages)
      else Stopwords.for(@stopwords)
      end
    end

    def entries_count = @entries_count ||= @scope.count

    def distinct_words = rows.size

    def total_occurrences = rows.sum(&:occurrences)

    def busiest = rows.max_by(&:occurrences)

    def empty? = rows.empty?

    private
      # ts_stat takes its inner query as a *string literal*, so the scope's SQL
      # is quoted rather than interpolated. User input only ever reaches it as a
      # bound value inside the relation.
      def query
        inner = Entry.connection.quote(@scope.select(:word_vector).to_sql)
        conditions = [ Entry.sanitize_sql_array([ "char_length(word) >= ?", @min_length ]) ]

        # Skipped entirely when there are no stopwords: an empty Ruby array
        # renders as NULL, and `= ANY (ARRAY[NULL])` is NULL, which would filter
        # out every row rather than none.
        #
        # unaccent() because the lists are stored folded ("mas") while
        # word_vector keeps accents ("más"). Inlined rather than wrapped in a
        # function: nothing is indexed on it, so STABLE is fine here.
        if stopword_list.any?
          conditions << Entry.sanitize_sql_array([
            "NOT (lower(unaccent(word)) = ANY (ARRAY[?]::text[]))", stopword_list.to_a
          ])
        end

        sql = Entry.sanitize_sql_array([ <<~SQL, @limit ])
          SELECT word, ndoc, nentry
          FROM ts_stat(#{inner})
          WHERE #{conditions.join(" AND ")}
          ORDER BY nentry DESC, ndoc DESC, word
          LIMIT ?
        SQL

        Entry.connection.select_rows(sql).map do |word, ndoc, nentry|
          Row.new(word: word, entries: ndoc.to_i, occurrences: nentry.to_i)
        end
      end

      # A full-corpus scan, so the result is memoised against the data it was
      # computed from. Any write moves updated_at or the count, which changes the
      # key -- no explicit invalidation to forget.
      def cached(&block)
        Rails.cache.fetch(cache_key, expires_in: 1.day, &block)
      end

      def cache_key
        [
          "analytics/word-frequency/v1",
          Digest::SHA256.hexdigest(@scope.to_sql)[0, 16],
          languages.join("-"),
          @stopwords.is_a?(Array) ? @stopwords.join("-") : @stopwords,
          @limit, @min_length,
          Entry.maximum(:updated_at)&.to_f,
          Entry.count
        ].join("/")
      end
  end
end
