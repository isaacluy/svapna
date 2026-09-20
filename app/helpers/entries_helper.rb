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
end
