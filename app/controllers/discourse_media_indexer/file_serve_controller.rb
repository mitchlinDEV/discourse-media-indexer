# frozen_string_literal: true

module DiscourseMediaIndexer
  class FileServeController < ::ApplicationController
    requires_plugin "discourse-media-indexer"

    def show
      # :token may be:
      #   - "<checksum>"
      #   - "<checksum>.ext"
      #   - "<filename>"
      #   - "<filename>.ext"
      raw = params[:token].to_s
      raise Discourse::NotFound if raw.blank?

      # Separate base + extension from token
      # e.g. "9b58...fabde.jpg" -> base="9b58...fabde", ext="jpg"
      base = raw.split(".").first
      ext_from_url = raw.split(".")[1]&.downcase

      # Try checksum lookup first
      media = DiscourseMediaIndexer::MediaFile.find_by(checksum: base)

      # If not found by checksum, fall back to filename (with or without extension)
      if media.nil?
        filename_with_ext = raw
        filename_without_ext = base

        media =
          DiscourseMediaIndexer::MediaFile.find_by(filename: filename_with_ext) ||
          DiscourseMediaIndexer::MediaFile.find_by(filename: filename_without_ext)
      end

      raise Discourse::NotFound if media.nil?

      root = SiteSetting.media_indexer_root_path.to_s
      base_root = root.sub(%r{/\z}, "")
      abs_path = File.join(base_root, media.path.to_s)

      raise Discourse::NotFound unless File.file?(abs_path)

      # Determine content type
      actual_ext = File.extname(abs_path).delete(".").downcase
      ext = actual_ext.presence || ext_from_url

      mime =
        if ext.present?
          Mime::Type.lookup_by_extension(ext) || "application/octet-stream"
        else
          "application/octet-stream"
        end

      send_file abs_path,
                disposition: "inline",
                type: mime
    end
  end
end
