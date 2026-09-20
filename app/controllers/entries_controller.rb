class EntriesController < ApplicationController
  before_action :set_entry, only: %i[show edit update destroy]

  # Plain listing for now. Real pagination and filtering arrive with search in M5.
  PAGE_SIZE = 50

  def index
    @entries = Entry.chronological.limit(PAGE_SIZE)
    @total = Entry.count
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
      redirect_to @entry, notice: "Entry created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @entry.update(entry_params)
      redirect_to @entry, notice: "Entry updated."
    else
      render :edit, status: :unprocessable_entity
    end
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
      params.expect(entry: %i[body written_on position language status source])
    end
end
