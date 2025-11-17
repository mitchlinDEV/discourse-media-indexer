# frozen_string_literal: true

class AddXpkeywordsToMediaFiles < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists?(:media_indexer_files)
    return if column_exists?(:media_indexer_files, :xpkeywords)

    add_column :media_indexer_files, :xpkeywords, :text
  end
end
