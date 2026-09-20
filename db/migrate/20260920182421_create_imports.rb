class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      # The note title parsed out of the file, e.g. "Sueños p.14".
      t.string  :source
      t.string  :filename
      t.integer :entries_count,   null: false, default: 0
      t.integer :duplicate_count, null: false, default: 0
      t.integer :skipped_count,   null: false, default: 0
      # Chunks we could not parse, kept so nothing is ever silently dropped.
      # Not named `errors`: that collides with ActiveModel::Errors and would
      # raise DangerousAttributeError.
      t.jsonb   :parse_errors,    null: false, default: []

      t.timestamps
    end

    # Undo is a Rails-level destroy so taggings are cleaned up too; the foreign
    # key is here to stop an entry pointing at an import that no longer exists.
    add_foreign_key :entries, :imports, on_delete: :cascade
  end
end
