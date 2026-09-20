class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :entries, through: :taggings

  before_validation { self.name = self.class.normalize(name) }

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }

  def self.normalize(name)
    name.to_s.strip.downcase
  end

  # Safe under concurrent imports: the unique index is the real guard.
  def self.find_or_create_by_name!(name)
    normalized = normalize(name)
    find_by(name: normalized) || create!(name: normalized)
  rescue ActiveRecord::RecordNotUnique
    find_by!(name: normalized)
  end

  def to_s = name
end
