# frozen_string_literal: true

module DiscourseMediaIndexer
  class FileServeController < ::ApplicationController
    requires_plugin "discourse-media-indexer"

    def show
      # Accept checksum or checksum.ext; strip extension if present
      raw = params[:checksum].to_s
      checksum = raw.split(".").first

      raise Discourse::NotFound if checksum.blank?

      media = MediaFile.find_by(checksum: checksum)
      raise Discourse::NotFound unless media

      root = SiteSetting.media_indexer_root_path.to_s
      base = root.sub(%r{/\z}, "")
      abs_path = File.join(base, media.path.to_s)

      raise Discourse::NotFound unless File.file?(abs_path)

      # Infer content type from actual file extension
      ext = File.extname(abs_path).delete(".").downcase
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
