class Entry < ApplicationRecord
  # Languages with a text search configuration in svapna_regconfig. Anything
  # else still saves -- Postgres falls back to 'simple' -- but loses stemming,
  # so keep this in step with the migration that defines the configurations.
  LANGUAGES = %w[es en].freeze

  enum :status, { draft: "draft", published: "published" }, validate: true

  belongs_to :import, optional: true

  # before_save rather than before_validation: the importer may write with
  # validate: false, and body_digest is NOT NULL.
  before_save :assign_body_digest

  validates :body, presence: true
  validates :written_on, presence: true
  validates :language, inclusion: { in: LANGUAGES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Newest first, with same-day entries in the order they appeared in the note.
  scope :chronological, -> { order(written_on: :desc, position: :asc, id: :asc) }
  scope :from_source, ->(source) { where(source: source) }
  scope :imported, -> { where.not(import_id: nil) }
  scope :written_between, ->(from, to) { where(written_on: from..to) }

  # An entry has no title: it is identified by its date.
  def to_s
    I18n.l(written_on, format: :long)
  end

  def excerpt(limit: 160)
    body.to_s.squish.truncate(limit)
  end

  # Collapsing whitespace and case means a re-import whose only difference is
  # formatting is still recognised as the same entry.
  def self.digest_for(body)
    Digest::SHA256.hexdigest(body.to_s.gsub(/\s+/, " ").strip.downcase)
  end

  private
    def assign_body_digest
      self.body_digest = self.class.digest_for(body)
    end
end
