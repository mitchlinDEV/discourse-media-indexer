# frozen_string_literal: true

class AddKindToMediaFiles < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:media_indexer_files)
    return if column_exists?(:media_indexer_files, :kind)

    add_column :media_indexer_files, :kind, :string
  end

  def down
    return unless table_exists?(:media_indexer_files)
    return unless column_exists?(:media_indexer_files, :kind)

    remove_column :media_indexer_files, :kind
  end
end
