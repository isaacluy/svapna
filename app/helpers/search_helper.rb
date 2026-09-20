module SearchHelper
  # Escape everything the entry contained, then turn our own markers into tags.
  # ts_headline does not escape the document it is given, so doing it in this
  # order is what keeps markup in an entry from reaching the page as markup.
  def highlighted(snippet)
    escaped = ERB::Util.html_escape(snippet.to_s)
      .gsub(EntrySearch::HIGHLIGHT_OPEN, "<mark>")
      .gsub(EntrySearch::HIGHLIGHT_CLOSE, "</mark>")
      .gsub(EntrySearch::FRAGMENT_DELIMITER, "<span class=\"text-ink-faint\"> &hellip; </span>")

    escaped.html_safe
  end

  # A link that keeps the current search and filters, changing only what is passed.
  def search_path_with(search, overrides = {})
    params = {
      q: search.query.presence,
      tag: search.tag,
      source: search.source,
      from: search.from,
      to: search.to,
      status: (search.status unless search.status == "published")
    }.merge(overrides).compact

    entries_path(params)
  end

  def search_summary(search)
    return "#{pluralize(search.total, 'entry')}" unless search.any_criteria?

    bits = []
    bits << "matching &ldquo;#{ERB::Util.html_escape(search.query)}&rdquo;".html_safe if search.searching?
    bits << "tagged #{ERB::Util.html_escape(search.tag)}" if search.tag
    bits << "from #{ERB::Util.html_escape(search.source)}" if search.source
    bits << date_window(search)
    bits << "including drafts" if search.status == "all"
    bits << "drafts only" if search.status == "draft"

    safe_join([ pluralize(search.total, "entry"), " ", safe_join(bits.compact, ", ") ])
  end

  private
    def date_window(search)
      return "since #{l(search.from, format: :long)}" if search.from && search.to.nil?
      return "up to #{l(search.to, format: :long)}" if search.to && search.from.nil?
      "between #{l(search.from, format: :long)} and #{l(search.to, format: :long)}" if search.from && search.to
    end
end
