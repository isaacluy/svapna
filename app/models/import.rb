# One row per import run, so every entry can be traced back to the file it came
# from and a bad run can be undone wholesale.
class Import < ApplicationRecord
  IMPORTANT_TAG = "important".freeze

  has_many :entries, dependent: :destroy

  scope :recent, -> { order(created_at: :desc) }

  def to_s
    [ source.presence || filename.presence || "Import", "##{id}" ].join(" ")
  end

  def undoable?
    entries.exists?
  end

  # An import that produced nothing is worth flagging: it usually means the
  # dividers were not recognised.
  def empty?
    entries_count.zero?
  end
end
