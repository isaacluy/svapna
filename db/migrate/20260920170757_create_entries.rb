class CreateEntries < ActiveRecord::Migration[8.1]
  def up
    create_table :entries do |t|
      t.text     :body,        null: false
      t.date     :written_on,  null: false
      # Orders entries that share a date (Apple Notes gives us several per day).
      t.integer  :position,    null: false, default: 0
      t.string   :language,    null: false, default: "es"
      t.string   :status,      null: false, default: "published"
      # The Apple Notes note title, e.g. "Sueños p.14". A grouping label, never
      # an entry title. NULL means the entry was written in Svapna.
      t.string   :source
      # SHA-256 of the normalised body; makes import idempotent.
      t.string   :body_digest, null: false
      # The imports table arrives in M3, which also adds the foreign key.
      t.bigint   :import_id

      t.timestamps
    end

    # Postgres recomputes both vectors on every write: no callbacks, no triggers,
    # and no way for them to drift out of sync with the body.
    #
    # Generated columns can only reference their own row, so tags and category
    # cannot be folded in -- they are filters, applied as joins at query time.
    execute <<~SQL
      ALTER TABLE entries
        ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
          setweight(to_tsvector(public.svapna_regconfig(language), coalesce(body, '')),   'A') ||
          setweight(to_tsvector(public.svapna_regconfig(language), coalesce(source, '')), 'C')
        ) STORED,
        -- Stock 'simple': lowercases but neither stems nor strips accents, so
        -- word-frequency results read as "sueños" rather than "suenos" or the
        -- stem "sueñ". Accent folding belongs to matching, not counting.
        ADD COLUMN word_vector tsvector GENERATED ALWAYS AS (
          to_tsvector('pg_catalog.simple', coalesce(body, ''))
        ) STORED;
    SQL

    add_index :entries, :search_vector, using: :gin
    add_index :entries, :word_vector,   using: :gin
    add_index :entries, [ :status, :written_on ], order: { written_on: :desc }
    add_index :entries, :import_id
    add_index :entries, :source

    # Partial on purpose. Idempotency is a property of importing; a plain unique
    # index would break the composer, where two new empty drafts on the same day
    # share the digest of an empty body.
    add_index :entries, [ :written_on, :body_digest ],
              unique: true,
              where: "import_id IS NOT NULL",
              name: "index_entries_on_import_dedupe"
  end

  def down
    drop_table :entries
  end
end
