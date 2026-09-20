class Tagging < ApplicationRecord
  belongs_to :entry
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :entry_id }
end
