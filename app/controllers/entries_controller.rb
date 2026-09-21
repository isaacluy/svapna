class EntriesController < ApplicationController
  before_action :set_entry, only: %i[show edit update destroy publish]

  # Browse and search are the same page: an empty query simply lists everything.
  def index
    @search = EntrySearch.new(search_params)
  end

  # Drafts get their own list so unfinished writing is easy to get back to.
  def drafts
    @search = EntrySearch.new(search_params.merge(status: "draft"))
    render :index
  end

  def show
  end

  def new
    @entry = Entry.new(written_on: Date.current, status: :draft)
  end

  def edit
  end

  def create
    @entry = Entry.new(entry_params)

    if @entry.save
      respond_to do |format|
        format.html { redirect_to after_save_path, notice: saved_notice }
        # Autosave: hand back where to send subsequent saves, since the entry
        # has only just acquired an id.
        format.json { render json: save_payload, status: :created }
      end
    else
      render_invalid(:new)
    end
  end

  def update
    if @entry.update(entry_params)
      respond_to do |format|
        format.html { redirect_to after_save_path, notice: saved_notice }
        format.json { render json: save_payload }
      end
    else
      render_invalid(:edit)
    end
  end

  def publish
    @entry.update!(status: :published)

    redirect_to @entry, notice: "Entry published."
  end

  def destroy
    @entry.destroy!
    redirect_to entries_path, notice: "Entry deleted.", status: :see_other
  end

  private
    def set_entry
      @entry = Entry.find(params[:id])
    end

    def entry_params
      params.expect(entry: %i[body written_on position language status source tag_list])
    end

    def search_params
      params.permit(:q, :tag, :source, :from, :to, :status, :page)
    end

    # Staying in the composer after an explicit save keeps a long writing
    # session in one place; publishing is what takes you to the reading view.
    def after_save_path
      @entry.draft? ? edit_entry_path(@entry) : entry_path(@entry)
    end

    def saved_notice
      @entry.draft? ? "Draft saved." : "Entry saved."
    end

    def save_payload
      {
        id: @entry.id,
        status: @entry.status,
        update_url: entry_path(@entry),
        show_url: entry_path(@entry),
        edit_url: edit_entry_path(@entry),
        publish_url: publish_entry_path(@entry),
        saved_at: @entry.updated_at.iso8601,
        words: @entry.word_count
      }
    end

    def render_invalid(view)
      respond_to do |format|
        format.html { render view, status: :unprocessable_entity }
        format.json { render json: { errors: @entry.errors.full_messages }, status: :unprocessable_entity }
      end
    end
end
