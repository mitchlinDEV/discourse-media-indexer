# frozen_string_literal: true

module DiscourseMediaIndexer
  class Tag < ::ActiveRecord::Base
    self.table_name = "media_indexer_tags"

    has_many :file_tags,
             class_name: "DiscourseMediaIndexer::FileTag",
             foreign_key: :media_indexer_tag_id,
             dependent: :destroy

    has_many :media_files,
             through: :file_tags,
             class_name: "DiscourseMediaIndexer::MediaFile"

    # Ensure all given tag names exist; returns Tag records.
    def self.ensure_all(names)
      normalized = Array(names)
        .map { |n| n.to_s.strip.downcase }
        .reject(&:blank?)
        .uniq

      return [] if normalized.empty?

      existing = where(name: normalized).to_a
      missing_names = normalized - existing.map(&:name)

      missing = missing_names.map { |n| create!(name: n) }

      existing + missing
    end
  end
end
