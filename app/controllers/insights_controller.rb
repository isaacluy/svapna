class InsightsController < ApplicationController
  STOPWORD_MODES = %w[auto none].freeze

  # Reuses EntrySearch, so "word frequency for these entries" is the same
  # filters as the entry list -- no second filtering language to learn.
  def show
    @search = EntrySearch.new(search_params)
    @stopword_mode = params[:stopwords].presence_in(STOPWORD_MODES) || "auto"
    @limit = (params[:limit].presence || 40).to_i

    @frequency = Analytics::WordFrequency.call(
      scope: @search.scope_for_analytics,
      stopwords: @stopword_mode.to_sym,
      limit: @limit
    )
  end

  private
    def search_params
      params.permit(:q, :tag, :source, :from, :to, :status)
    end
end
