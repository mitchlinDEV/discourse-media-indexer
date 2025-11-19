// assets/javascripts/discourse/helpers/media-indexer-file-url.js
import { helper } from "@ember/component/helper";

/**
 * Builds a public URL for a media file based on:
 *   - Site setting: media_indexer_public_prefix
 *   - Media item: { path: "images/2025/..." }
 *
 * If the prefix is blank, it falls back to just "path".
 */
export default helper(function mediaIndexerFileUrl([item]) {
  if (!item) {
    return "";
  }

  const prefix = (Discourse.SiteSettings.media_indexer_public_prefix || "").trim();
  const path = (item.path || "").replace(/^\/+/, "");

  if (!prefix) {
    // Fallback: just return the raw path; may be a full URL if you store it that way
    return path;
  }

  if (prefix.endsWith("/")) {
    return `${prefix}${path}`;
  } else {
    return `${prefix}/${path}`;
  }
});
