class HomeController < ApplicationController
  def index
    @entry_count = Entry.count
    @earliest = Entry.minimum(:written_on)
    @recent = Entry.published.chronological.limit(5)
  end
end
