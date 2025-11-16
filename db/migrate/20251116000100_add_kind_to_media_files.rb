# frozen_string_literal: true

class AddKindToMediaFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_media_indexer_media_files, :kind, :string
  end
end
