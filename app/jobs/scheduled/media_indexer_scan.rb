# frozen_string_literal: true

require "find"
require "digest"

module ::Jobs
  class MediaIndexerScan < ::Jobs::Scheduled
    every 1.hour

    def execute(_args = {})
      root = SiteSetting.media_indexer_root_path
      if root.blank?
        Rails.logger.warn("[MediaIndexer] root path is blank; aborting scan")
        return
      end

      unless File.directory?(root)
        Rails.logger.warn("[MediaIndexer] root path '#{root}' is not a directory; aborting scan")
        return
      end

      extensions = normalized_extensions
      Rails.logger.info("[MediaIndexer] scan starting at '#{root}', #{extensions.size} extensions")

      tracked = 0

      Find.find(root) do |abs_path|
        next unless File.file?(abs_path)

        ext = File.extname(abs_path).downcase.delete(".")
        next if ext.blank?
        next unless extensions.include?(ext)

        media_file = index_file(root, abs_path, ext)
        tracked += 1 if media_file
      end

      Rails.logger.info("[MediaIndexer] scan finished; tracked #{tracked} files")
    rescue StandardError => e
      Rails.logger.error(
        "[MediaIndexer] scan failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}",
      )
    end

    private

    def normalized_extensions
      raw = SiteSetting.media_indexer_extensions.to_s
      raw
        .split(/[,\s|]+/)
        .map { |e| e.downcase.delete(".") }
        .reject(&:blank?)
        .uniq
    end

    def index_file(root, abs_path, ext)
      rel_path = abs_path.sub(%r{\A#{Regexp.escape(root)}/?}, "")

      stat = File.stat(abs_path) rescue nil

      media_file = ::DiscourseMediaIndexer::MediaFile.find_or_initialize_by(path: rel_path)

      kind = image_extension?(ext) ? "image" : "video"
      media_file.kind = kind
      media_file.size = stat&.size

      # Only compute checksum once; this is relatively expensive
      if media_file.checksum.blank?
        media_file.checksum = Digest::SHA1.file(abs_path).hexdigest rescue nil
      end

      xp = extract_keywords(abs_path, kind)
      media_file.xpkeywords = xp.join("|") if xp.present?

      media_file.save!

      update_tags_for(media_file, xp)

      media_file
    end

    IMAGE_EXTENSIONS = %w[
      jpg jpeg jpe png gif webp bmp tif tiff heic heif avif jxl
    ].freeze

    def image_extension?(ext)
      IMAGE_EXTENSIONS.include?(ext)
    end

    # Extract tags/keywords from multiple locations:
    # - Images: Exif / IFD0: XPKeywords, XPComment, Subject, Keywords, Comment, Title, Description, TagsList
    # - Video: QuickTime/Track2/Keys: Keywords, Comment, Title, Description, Subject, XPKeywords
    # - Any other tag whose name looks like *Keyword(s)*, *Comment*, *Title*, or Keys+Keywords.
    # Tags are separated by ';' (primary), but we also split on ',' and '|' for robustness.
    def extract_keywords(abs_path, kind)
      require "mini_exiftool"

      exif = MiniExiftool.new(abs_path)

      image_keys = %w[
        XPKeywords
        XPComment
        Subject
        Keywords
        Comment
        Title
        Description
        TagsList
      ]

      video_keys = %w[
        Keywords
        Comment
        Title
        Description
        Subject
        XPKeywords
      ]

      keys_to_check =
        if kind == "image"
          image_keys
        else
          video_keys
        end

      raw_values = []

      # 1) Explicit, well-known fields
      keys_to_check.each do |k|
        val = exif[k]
        next if val.nil? || (val.respond_to?(:empty?) && val.empty?)

        if val.is_a?(Array)
          raw_values.concat(val)
        else
          raw_values << val
        end
      end

      # 2) Catch-all for other metadata keys that look like keyword/comment/title fields,
      #    including QuickTime keys like "Keys:Keywords", "Track2 Itemlist Comment", etc.
      exif.to_hash.each do |tag_name, val|
        next if val.nil? || (val.respond_to?(:empty?) && val.empty?)

        name = tag_name.to_s

        # Skip if we already handled this as an explicit key
        next if keys_to_check.include?(name)

        # Match things like:
        # - "...Keywords" or "...Keyword"
        # - "...Comment"
        # - "...Title"
        # - "Keys:Keywords", "Keys Keywords", etc.
        next unless
          name =~ /(keyword|keywords)\b/i ||
          name =~ /\bcomment\b/i ||
          name =~ /\btitle\b/i ||
          name =~ /keys.*keywords/i

        if val.is_a?(Array)
          raw_values.concat(val)
        else
          raw_values << val
        end
      end

      raw_values
        .flat_map { |v| v.to_s.split(/[;,\|]/) } # primary separator ';', but also ',' and '|'
        .map { |v| v.to_s.strip }
        .reject(&:blank?)
        .uniq
    rescue StandardError
      []
    end

    def update_tags_for(media_file, xpkeywords)
      xpkeywords ||= []
      return if xpkeywords.empty?

      # Reset associations so DB matches current tags exactly
      media_file.file_tags.destroy_all

      xpkeywords.each do |name|
        tag = ::DiscourseMediaIndexer::Tag.find_or_create_by!(name: name)
        ::DiscourseMediaIndexer::FileTag.find_or_create_by!(
          media_file_id: media_file.id,
          tag_id: tag.id,
        )
      end
    end
  end
end
