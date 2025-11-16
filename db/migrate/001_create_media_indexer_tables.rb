# frozen_string_literal: true

class CreateMediaIndexerTables < ActiveRecord::Migration[7.0]
  def change
    create_table :media_indexer_files do |t|
      t.string  :path,      null: false                 # full absolute path
      t.string  :filename,  null: false
      t.string  :extension, null: false
      t.bigint  :size
      t.string  :sha1
      t.datetime :mtime
      t.integer :width
      t.integer :height
      t.float   :duration
      t.timestamps
    end

    add_index :media_indexer_files, :path, unique: true
    add_index :media_indexer_files, :sha1

    create_table :media_indexer_tags do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_index :media_indexer_tags, :name, unique: true

    create_table :media_indexer_file_tags do |t|
      t.integer :media_indexer_file_id, null: false
      t.integer :media_indexer_tag_id,  null: false
      t.timestamps
    end

    add_index :media_indexer_file_tags,
              [:media_indexer_file_id, :media_indexer_tag_id],
              unique: true,
              name: "idx_media_indexer_file_tags_unique"
  end
end
