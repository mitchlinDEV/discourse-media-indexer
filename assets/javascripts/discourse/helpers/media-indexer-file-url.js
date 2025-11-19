// assets/javascripts/discourse/helpers/media-indexer-url.js
import { helper } from "@ember/component/helper";

/**
 * Build a public URL for a media item.
 *
 * Currently:
 *   /media/<filename>
 *
 * Example:
 *   filename = "9b5834326d18602d4587462cb0fabbde.jpg"
 *   => "/media/9b5834326d18602d4587462cb0fabbde.jpg"
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
