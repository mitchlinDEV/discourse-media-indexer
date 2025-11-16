# frozen_string_literal: true

module DiscourseMediaIndexer
  class FileTag < ::ActiveRecord::Base
    self.table_name = "media_indexer_file_tags"

    belongs_to :media_file,
               class_name: "DiscourseMediaIndexer::MediaFile",
               foreign_key: :media_indexer_file_id

    belongs_to :tag,
               class_name: "DiscourseMediaIndexer::Tag",
               foreign_key: :media_indexer_tag_id
  end
end
