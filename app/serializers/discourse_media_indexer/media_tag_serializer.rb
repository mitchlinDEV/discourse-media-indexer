# frozen_string_literal: true

module DiscourseMediaIndexer
  class MediaTagSerializer < ::ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :media_count

    def slug
      # Use existing slug if present
      return object.slug if object.respond_to?(:slug) && object.slug.present?

      object.name.to_s.parameterize
    end

    def media_count
      # Prefer a counter cache if it exists
      if object.respond_to?(:media_files_count)
        object.media_files_count.to_i
      else
        object.media_files.count
      end
    end
  end
end
