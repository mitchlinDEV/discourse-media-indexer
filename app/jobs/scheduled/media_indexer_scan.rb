# frozen_string_literal: true
require "set"
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

      # Extract EXIF/IPTC/XMP/QuickTime keywords
      keywords = extract_keywords(abs_path, kind)

      # Store raw keywords in the xpkeywords column (if present on the model)
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

    # Collect keywords/tags from a file (images + videos)
    # kind is currently unused but kept for future format-specific logic
    def extract_keywords(abs_path, kind)
      keywords = []
      seen = Set.new

      begin
        exif = MiniExiftool.new(abs_path)

        # Explicit keys across many schemas/namespaces
        preferred_keys = [
          "XPKeywords",          # Windows XP / classic tags
          "Keywords",            # generic IPTC/XMP keywords
          "Subject",             # often used as keywords
          "Category",            # Microsoft/Photos category
          "Tags",                # generic tags field
          "MicrosoftKeywords",
          "MicrosoftCategory",

          # XMP / PDF
          "XMP-dc:Subject",
          "XMP-pdf:Keywords",
          "PDF:Keywords",

          # QuickTime / MP4 (videos)
          "QuickTime:Keywords",
          "QuickTime:Category",
          "QuickTime:Genre",
        ]

        # 1) Explicit keys
        preferred_keys.each do |key|
          value = safe_exif_get(exif, key)
          normalize_keywords_value(value).each do |tag|
            down = tag.downcase
            next if seen.include?(down)

            seen << down
            keywords << tag
          end
        end

        # 2) Generic sweep: any key that ends with
        #    Keywords / Keyword / Subject / Category / Tags / Tag
        if exif.respond_to?(:to_hash)
          exif.to_hash.each do |k, v|
            key_str = k.to_s
            next unless key_str =~ /(keywords?|subject|category|tags?)$/i

            normalize_keywords_value(v).each do |tag|
              down = tag.downcase
              next if seen.include?(down)

              seen << down
              keywords << tag
            end
          end
        end
      rescue MiniExiftool::Error => e
        Rails.logger.warn(
          "[MediaIndexer] EXIF read failed for #{abs_path}: #{e.class}: #{e.message}",
        )
      end

      keywords
    end

    # Normalize a metadata value into a flat array of tag strings.
    # Handles arrays and scalar values, splitting on common list separators.
    def normalize_keywords_value(value)
      return [] if value.nil?

      raw_values =
        if value.is_a?(Array)
          value.map(&:to_s)
        else
          [value.to_s]
        end

      out = []
      raw_values.each do |raw|
        raw.split(/[;,|\*]/).each do |frag|
          tag = frag.strip
          out << tag unless tag.empty?
        end
      end

      out
    end

    def safe_exif_get(exif, key)
      exif[key]
    rescue StandardError
      nil
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
