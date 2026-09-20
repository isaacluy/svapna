class ImportsController < ApplicationController
  before_action :set_import, only: %i[show destroy]

  def index
    @imports = Import.recent.includes(:entries)
  end

  def show
    @entries = @import.entries.chronological
  end

  def new
  end

  def create
    sources = uploaded_sources
    sources << [ nil, pasted_text ] if pasted_text.present?

    if sources.empty?
      flash.now[:alert] = "Paste some text or choose at least one file."
      return render :new, status: :unprocessable_entity
    end

    imports = sources.map { |filename, text| NotesImport::Runner.import(text, filename: filename) }

    if imports.one?
      redirect_to imports.first, notice: summary_for(imports.first)
    else
      redirect_to imports_path, notice: "Imported #{imports.size} files, #{imports.sum(&:entries_count)} entries."
    end
  end

  def destroy
    count = @import.entries.count
    @import.destroy!

    redirect_to imports_path,
                notice: "Undid #{@import.source.presence || 'the import'}, deleting #{pluralize(count, 'entry')}.",
                status: :see_other
  end

  private
    def set_import
      @import = Import.find(params[:id])
    end

    def pasted_text
      params.dig(:import, :text).to_s
    end

    # Each file becomes its own Import, so one bad file can be undone without
    # touching the others.
    def uploaded_sources
      Array(params.dig(:import, :files)).reject(&:blank?).map do |file|
        [ file.original_filename, file.read.force_encoding(Encoding::UTF_8) ]
      end
    end

    def summary_for(import)
      parts = [ "#{pluralize(import.entries_count, 'entry')} imported" ]
      parts << "#{import.duplicate_count} already present" if import.duplicate_count.positive?
      parts << "#{import.skipped_count} skipped" if import.skipped_count.positive?
      parts.join(", ") + "."
    end

    def pluralize(...) = ActionController::Base.helpers.pluralize(...)
end
