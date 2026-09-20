class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      # Stored already downcased by the model, so a plain unique index is enough
      # and we avoid pulling in citext.
      t.string :name, null: false

      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :taggings do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :tag,   null: false, foreign_key: true

      t.timestamps
    end
    add_index :taggings, [ :entry_id, :tag_id ], unique: true
  end
end
