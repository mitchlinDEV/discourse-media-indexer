# frozen_string_literal: true

module DiscourseMediaIndexer
  class MediaFileSerializer < ::ApplicationSerializer
    attributes :id,
               :path,
               :filename,
               :extension,
               :size,
               :kind,
               :checksum,
               :xpkeywords,
               :folder,
               :created_at,
               :updated_at,
               :url

    has_many :tags, serializer: DiscourseMediaIndexer::MediaTagSerializer

    def folder
      # If you later add a DB column "folder", this will use it automatically.
      return object.folder if object.respond_to?(:folder) && object.folder.present?
      return nil if object.path.blank?

      object.path.split("/").first
    end

    def url
      # For now just return the relative path.
      # Frontend can prepend a base URL or route to serve the file.
      object.path
    end

    def xpkeywords
      raw = object.xpkeywords
      return [] if raw.blank?

      if raw.is_a?(Array)
        raw
      else
        raw.to_s.split(/[,;]+/).map { |t| t.strip }.reject(&:blank?)
      end
    end
  end
end
