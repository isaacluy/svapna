class Entry < ApplicationRecord
  # Language => the Postgres text search configuration that stems it.
  # Must stay in step with svapna_regconfig (see the EnableSearchExtensions
  # migration); anything not listed here still saves, but Postgres falls back
  # to 'simple' and it loses stemming.
  SEARCH_CONFIGS = {
    "es" => "public.svapna_es",
    "en" => "public.svapna_en"
  }.freeze

  LANGUAGES = SEARCH_CONFIGS.keys.freeze

  enum :status, { draft: "draft", published: "published" }, validate: true

  belongs_to :import, optional: true

  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # before_save rather than before_validation: the importer may write with
  # validate: false, and body_digest is NOT NULL.
  before_save :assign_body_digest
  # A blank source means "written here". Left as "", it would appear as an empty
  # option in the source filter and break `where.not(source: nil)`.
  before_save -> { self.source = source.presence }

  # Tags are edited as a comma-separated string. Applied after save so a new
  # entry has an id to attach taggings to.
  after_save :sync_tag_list, if: -> { @tag_list_assigned }

  validates :body, presence: true
  validates :written_on, presence: true
  validates :language, inclusion: { in: LANGUAGES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Newest first, with same-day entries in the order they appeared in the note.
  scope :chronological, -> { order(written_on: :desc, position: :asc, id: :asc) }
  scope :from_source, ->(source) { where(source: source) }
  scope :tagged_with, ->(name) { joins(:tags).where(tags: { name: Tag.normalize(name) }) }
  scope :imported, -> { where.not(import_id: nil) }
  scope :written_between, ->(from, to) { where(written_on: from..to) }

  # An entry has no title: it is identified by its date.
  def to_s
    I18n.l(written_on, format: :long)
  end

  # Rough, and deliberately so: it is a writing aid, not a statistic.
  # Analytics::WordFrequency is the accurate count.
  def word_count = body.to_s.scan(/[[:alnum:]]+/).size

  def excerpt(limit: 160)
    body.to_s.squish.truncate(limit)
  end

  # Collapsing whitespace and case means a re-import whose only difference is
  # formatting is still recognised as the same entry.
  def self.digest_for(body)
    Digest::SHA256.hexdigest(body.to_s.gsub(/\s+/, " ").strip.downcase)
  end

  # Comma-separated, for the form field.
  def tag_list
    return @tag_list if @tag_list_assigned

    tags.sort_by(&:name).map(&:name).join(", ")
  end

  def tag_list=(value)
    @tag_list = value.to_s
    @tag_list_assigned = true
  end

  def tag!(name)
    tags << Tag.find_or_create_by_name!(name) unless tagged_with?(name)
  end

  def tagged_with?(name)
    tags.any? { |tag| tag.name == Tag.normalize(name) }
  end

  private
    def sync_tag_list
      names = @tag_list.split(",").map { |name| Tag.normalize(name) }.reject(&:blank?).uniq

      keep = names.map { |name| Tag.find_or_create_by_name!(name) }
      taggings.where.not(tag_id: keep.map(&:id)).destroy_all
      (keep - tags.reload).each { |tag| tags << tag }

      @tag_list_assigned = false
      tags.reset
    end

    def assign_body_digest
      self.body_digest = self.class.digest_for(body)
    end
end
