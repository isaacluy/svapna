# Search and filtering over entries.
#
#   EntrySearch.new(q: "sueno", tag: "important", page: 2)
#
# Hand-written rather than pg_search: that gem supports neither multiple
# dictionaries in one query nor a per-row language configuration, and this app
# needs both.
class EntrySearch
  PER_PAGE = 20
  STATUSES = %w[published draft all].freeze

  # Matches are delimited with private-use codepoints rather than <mark>, so the
  # snippet can be HTML-escaped wholesale and only these markers turned into
  # tags afterwards. Asking Postgres for literal <mark> would mean sanitising
  # instead, and Rails' sanitize strips a disallowed tag while keeping its text
  # -- so "<script>alert(1)</script>" would render as a bare "alert(1)".
  HIGHLIGHT_OPEN = "\uE000".freeze
  HIGHLIGHT_CLOSE = "\uE001".freeze
  FRAGMENT_DELIMITER = "\uE002".freeze

  # The query parsed under every configured language, OR'd together. Recall
  # matters more than precision here: a Spanish query should still find an
  # English entry, and ranking sorts out the rest.
  #
  # Built once at load time from a constant, so every call site passes user
  # input as a bind rather than interpolating SQL.
  TSQUERY_SQL = Entry::SEARCH_CONFIGS.values.map { "websearch_to_tsquery(?, ?)" }.join(" || ").freeze
  MATCH_SQL = "search_vector @@ (#{TSQUERY_SQL})".freeze
  RANK_SQL = "ts_rank_cd(search_vector, (#{TSQUERY_SQL})) DESC".freeze
  HEADLINE_SQL = "SELECT id, ts_headline(public.svapna_regconfig(language), body, " \
                 "(#{TSQUERY_SQL}), ?) FROM entries WHERE id IN (?)".freeze

  # ts_headline re-parses the original document, so it is only ever run over
  # the handful of rows actually being shown.
  HEADLINE_OPTIONS = "StartSel=#{HIGHLIGHT_OPEN}, StopSel=#{HIGHLIGHT_CLOSE}, " \
                     "MaxFragments=2, MinWords=8, MaxWords=26, " \
                     "FragmentDelimiter=#{FRAGMENT_DELIMITER}".freeze

  attr_reader :query, :tag, :source, :from, :to, :status

  def initialize(params = {})
    @query  = params[:q].to_s.strip
    @tag    = params[:tag].presence
    @source = params[:source].presence
    @from   = parse_date(params[:from])
    @to     = parse_date(params[:to])
    @status = params[:status].presence_in(STATUSES) || "published"
    @requested_page = [ params[:page].to_i, 1 ].max
  end

  # Clamped, so ?page=99 on a one-page result shows page 1 rather than an
  # empty list and a nonsensical "showing 1961-5".
  def page = @page ||= @requested_page.clamp(1, total_pages)

  def searching? = query.present?

  def filtered? = tag.present? || source.present? || from.present? || to.present? || status != "published"

  def any_criteria? = searching? || filtered?

  def total = @total ||= scope.count

  def entries = @entries ||= paginated.to_a

  def total_pages = [ (total / PER_PAGE.to_f).ceil, 1 ].max

  def first_on_page = total.zero? ? 0 : offset + 1

  def last_on_page = [ offset + PER_PAGE, total ].min

  def previous_page = page > 1 ? page - 1 : nil

  def next_page = page < total_pages ? page + 1 : nil

  # { entry_id => highlighted snippet }, computed for the current page only.
  def highlights
    return {} unless searching? && entries.any?

    @highlights ||= Entry.connection.select_rows(
      Entry.sanitize_sql_array([ HEADLINE_SQL, *tsquery_binds, HEADLINE_OPTIONS, entries.map(&:id) ])
    ).to_h
  end

  # Tag counts for the current filters, so the facets reflect what is actually
  # reachable rather than the whole table.
  def tag_facets
    @tag_facets ||= Tag.joins(:taggings)
                       .where(taggings: { entry_id: scope.select(:id) })
                       .group("tags.name")
                       .order(Arel.sql("count(*) DESC, tags.name"))
                       .count
  end

  # Drafts excluded by the current filter. Surfaced in the UI so a draft never
  # just seems to have vanished.
  def hidden_draft_count
    return 0 unless status == "published"

    @hidden_draft_count ||= scope.unscope(where: :status).where(status: "draft").count
  end

  def sources
    @sources ||= Entry.where.not(source: nil).distinct.order(:source).pluck(:source)
  end

  private
    def scope
      @scope ||= begin
        relation = Entry.all
        relation = relation.where(status: status) unless status == "all"
        relation = relation.tagged_with(tag) if tag
        relation = relation.where(source: source) if source
        relation = relation.where(written_on: from..) if from && to.nil?
        relation = relation.where(written_on: ..to) if to && from.nil?
        relation = relation.where(written_on: from..to) if from && to
        relation = relation.where(MATCH_SQL, *tsquery_binds) if searching?
        relation
      end
    end

    def paginated
      ordered.limit(PER_PAGE).offset(offset)
    end

    def ordered
      if searching?
        # Rank first, then date, so equally relevant entries read newest-first.
        scope.order(Arel.sql(Entry.sanitize_sql_array([ RANK_SQL, *tsquery_binds ])))
             .order(written_on: :desc, position: :asc, id: :asc)
      else
        scope.chronological
      end
    end

    def offset = (page - 1) * PER_PAGE

    # One [config, query] pair per configured language, matching the ? slots
    # in TSQUERY_SQL.
    def tsquery_binds
      @tsquery_binds ||= Entry::SEARCH_CONFIGS.values.flat_map { |config| [ config, query ] }
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
end
