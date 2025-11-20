// assets/javascripts/discourse/helpers/media-indexer-url.js
import { helper } from "@ember/component/helper";

/**
 * Build a public URL for a media item.
 * Currently:
 *   /media/<filename>
 */
export default helper(function mediaIndexerUrl([item]) {
  if (!item) {
    return "";
  }

  const filename = (item.filename || "").trim();
  if (!filename) {
    return "";
  }

  return `/media/${filename}`;
});
