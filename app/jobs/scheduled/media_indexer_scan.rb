# frozen_string_literal: true
require "mini_exiftool"
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

    def image_extension?(ext)
      # Adjust if you want to treat webp/gif differently
      %w[jpg jpeg png gif webp].include?(ext.to_s.downcase)
    end

    def index_file(root, abs_path, ext)
      rel_path =
        abs_path.sub(
          %r{\A#{Regexp.escape(root.to_s.sub(%r{/\z}, ""))}/?},
          "",
        )

      stat = begin
        File.stat(abs_path)
      rescue StandardError
        nil
      end

      media_file =
        ::DiscourseMediaIndexer::MediaFile.find_or_initialize_by(path: rel_path)

      media_file.filename = File.basename(abs_path)
      media_file.extension = ext

      kind = image_extension?(ext) ? "image" : "video"
      media_file.kind = kind
      media_file.size = stat&.size

      # Compute a checksum only once (optional but useful)
      if media_file.checksum.blank? && File.readable?(abs_path)
        digest = Digest::SHA256.file(abs_path).hexdigest
        media_file.checksum = digest
      end

      # Extract EXIF/IPTC/XMP keywords
      keywords = extract_keywords(abs_path, kind)

      # Store raw keywords in the xpkeywords column (if present on the model)
      # You can change the join character if you prefer commas/semicolons
      media_file.xpkeywords = keywords.join("|") if media_file.respond_to?(:xpkeywords=)

      media_file.save!

      # Update Tag and FileTag join table
      update_tags_for(media_file, keywords)

      media_file
    rescue StandardError => e
      Rails.logger.error(
        "[MediaIndexer] index_file failed for #{abs_path}: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}",
      )
      nil
    end

    def extract_keywords(abs_path, kind)
      keywords = []

      begin
        exif = MiniExiftool.new(abs_path)

        # Windows XP-style keywords
        xp = exif["XPKeywords"]
        keywords.concat(normalize_keywords_value(xp))

        # Generic IPTC/XMP keywords
        kw = exif["Keywords"]
        keywords.concat(normalize_keywords_value(kw))

        # Sometimes people use Subject as a keyword-ish field
        subj = exif["Subject"]
        keywords.concat(normalize_keywords_value(subj))
      rescue MiniExiftool::Error => e
        Rails.logger.warn(
          "[MediaIndexer] EXIF read failed for #{abs_path}: #{e.class}: #{e.message}",
        )
      end

      # Cleanup: strip, drop blanks, dedupe
      keywords
        .map { |k| k.to_s.strip }
        .reject(&:blank?)
        .uniq
    end

    def normalize_keywords_value(value)
      return [] if value.nil?

      case value
      when Array
        value
      else
        # XPKeywords often comes back as "tag1; tag2;tag3"
        value.to_s.split(/[;,]/)
      end
    end

    def update_tags_for(media_file, keywords)
      keywords ||= []
      cleaned = keywords.map { |k| k.to_s.strip.downcase }.reject(&:blank?).uniq
      return if cleaned.blank?

      # Clear existing tag links for this file
      ::DiscourseMediaIndexer::FileTag.where(
        media_indexer_file_id: media_file.id,
      ).delete_all

      cleaned.each do |name|
        tag = ::DiscourseMediaIndexer::Tag.find_or_create_by!(name: name)
        ::DiscourseMediaIndexer::FileTag.create!(
          media_indexer_file_id: media_file.id,
          media_indexer_tag_id: tag.id,
        )
      end
    end
  end
end
