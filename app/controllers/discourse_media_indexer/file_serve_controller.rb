# frozen_string_literal: true

module DiscourseMediaIndexer
  class FileServeController < ::ApplicationController
    requires_plugin "discourse-media-indexer"

    def show
      # /media/:token(.:format)
      # For /media/9b58...fabbde.jpg we get:
      #   params[:token]  = "9b58...fabbde"
      #   params[:format] = "jpg"
      base = params[:token].to_s
      ext_from_url = params[:format].to_s.presence

      raise Discourse::NotFound if base.blank?

      # First try by filename, which is what you’re using now
      filename_with_ext =
        if ext_from_url
          "#{base}.#{ext_from_url}"
        else
          base
        end

      media =
        DiscourseMediaIndexer::MediaFile.find_by(filename: filename_with_ext) ||
        DiscourseMediaIndexer::MediaFile.find_by(filename: base)

      raise Discourse::NotFound if media.nil?

      root = SiteSetting.media_indexer_root_path.to_s
      base_root = root.sub(%r{/\z}, "")
      abs_path = File.join(base_root, media.path.to_s)

      raise Discourse::NotFound unless File.file?(abs_path)

      # Determine MIME type from actual file extension
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
