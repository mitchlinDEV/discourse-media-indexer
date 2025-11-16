# frozen_string_literal: true

module DiscourseMediaIndexer
  class MediaFile < ::ActiveRecord::Base
    self.table_name = "media_indexer_files"

    has_many :file_tags,
             class_name: "DiscourseMediaIndexer::FileTag",
             foreign_key: :media_indexer_file_id,
             dependent: :destroy

    has_many :tags,
             through: :file_tags,
             class_name: "DiscourseMediaIndexer::Tag"

    scope :images, -> { where(extension: %w[jpg jpeg png gif webp bmp tiff tif heic heif]) }

    scope :videos, -> {
      where(extension: %w[
        mp4 m4v mkv webm avi mov wmv flv mpg mpeg ts m2ts ogv 3gp 3g2
      ])
    }

    def image?
      self.class.images.where(id: id).exists?
    end

    def video?
      self.class.videos.where(id: id).exists?
    end
  end
end
