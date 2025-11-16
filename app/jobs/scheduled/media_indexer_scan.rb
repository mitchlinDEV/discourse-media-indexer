# frozen_string_literal: true

# Scheduled job for the media indexer.
#
# This job:
#   - walks the configured root folder
#   - finds media files with allowed extensions
#   - stores/updates records in media_indexer_files
#   - extracts XPKeywords / Keywords as tags (if exiftool support is available)
#   - syncs those into media_indexer_tags + media_indexer_file_tags
#   - removes DB rows for files that no longer exist

require "find"
require "digest/sha1"

module ::DiscourseMediaIndexer
  class Scanner
    def self.run
      return unless SiteSetting.media_index_enabled

      root = SiteSetting.media_index_root_path.to_s.strip
      if root.blank? || !::File.directory?(root)
        Rails.logger.warn("[MediaIndexer] root path '#{root}' is not a directory; aborting scan")
        return
      end

      # Combine configured extensions with a broad default set
      configured_exts =
        SiteSetting.media_index_extensions.to_s.split(/[|,;\s]+/).map(&:downcase)

      default_exts = %w[
        jpg jpeg png gif webp bmp tif tiff heic heif
        mp4 m4v mkv webm avi mov wmv flv mpg mpeg ts m2ts ogv 3gp 3g2
      ]

      allowed_exts = (configured_exts + default_exts).map(&:downcase).uniq

      Rails.logger.info("[MediaIndexer] scan starting at '#{root}', #{allowed_exts.size} extensions")

      seen_paths = []

      Find.find(root) do |path|
        next unless ::File.file?(path)

        ext = ::File.extname(path).delete(".").downcase
        next if ext.blank?
        next unless allowed_exts.include?(ext)

        seen_paths << path

        begin
          stat = ::File.stat(path)
        rescue StandardError => e
          Rails.logger.warn("[MediaIndexer] stat failed for #{path}: #{e.message}")
          next
        end

        relative = path.sub(/\A#{Regexp.escape(root)}\/?/, "")
        filename = ::File.basename(path)

        media = DiscourseMediaIndexer::MediaFile.find_or_initialize_by(path: path)
        media.filename  = filename
        media.extension = ext
        media.size      = stat.size
        media.mtime     = stat.mtime

        # SHA1 for dedupe
        begin
          media.sha1 = Digest::SHA1.file(path).hexdigest
        rescue StandardError => e
          Rails.logger.warn("[MediaIndexer] sha1 failed for #{path}: #{e.message}")
        end

        # TODO: width/height and duration can be filled using ffprobe / mini_magick later
        media.save!

        # XPKeywords / Keywords -> tags
        tags = extract_keywords(path)
        if tags.any?
          tag_records = DiscourseMediaIndexer::Tag.ensure_all(tags)
          media.tags = tag_records
        else
          media.tags.clear if media.tags.any?
        end
      end

      # Remove DB entries for files that disappeared
      if seen_paths.any?
        DiscourseMediaIndexer::MediaFile
          .where("path LIKE ?", "#{root}%")
          .where.not(path: seen_paths)
          .destroy_all
      end

      Rails.logger.info("[MediaIndexer] scan finished; tracked #{seen_paths.size} files")
    rescue StandardError => e
      Rails.logger.error("[MediaIndexer] scan failed: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    # Attempt to read XPKeywords / Keywords from file metadata.
    # Uses mini_exiftool if available; otherwise logs and returns [].
    def self.extract_keywords(path)
      begin
        require "mini_exiftool"
      rescue LoadError
        Rails.logger.debug("[MediaIndexer] mini_exiftool not available; skipping keywords for #{path}")
        return []
      end

      exif = MiniExiftool.new(path)

      raw =
        exif["XPKeywords"] ||
        exif["Keywords"]   ||
        exif["Subject"]

      values =
        case raw
        when String
          raw.split(/[;,]/)
        when Array
          raw
        else
          []
        end

      values
        .map { |v| v.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }
        .map(&:strip)
        .reject(&:blank?)
        .uniq
    rescue StandardError => e
      Rails.logger.warn("[MediaIndexer] failed to read keywords for #{path}: #{e.message}")
      []
    end
  end
end

class ::Jobs::MediaIndexerScan < ::Jobs::Scheduled
  # How often to run – you can adjust this later in code or by using a
  # per-job setting if needed.
  every 1.hour

  def execute(_args)
    ::DiscourseMediaIndexer::Scanner.run
  end
end
