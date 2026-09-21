class HomeController < ApplicationController
  def index
    @entry_count = Entry.published.count
    @earliest = Entry.published.minimum(:written_on)
    @drafts = Entry.draft.chronological.limit(3)
    @recent = Entry.published.chronological.limit(5)
  end
end
