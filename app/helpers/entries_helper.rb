module EntriesHelper
  # Entries have no title, so the date does that work everywhere.
  def entry_date(entry)
    tag.time entry.written_on.strftime("%-d %B %Y"),
             datetime: entry.written_on.iso8601
  end

  def entry_day_and_month(entry)
    entry.written_on.strftime("%-d %b")
  end

  def tag_pill(tag)
    marker = tag.name == Import::IMPORTANT_TAG
    content_tag :span, tag.name, class: "tag #{'tag-marker' if marker}"
  end

  # Entries ordered for display, with their tags preloaded.
  def sorted_tags(entry) = entry.tags.sort_by(&:name)
end
