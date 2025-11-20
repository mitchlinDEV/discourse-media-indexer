// assets/javascripts/discourse/routes/media-browser.js
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
  model() {
    // For now, just load the first 100 items
    return ajax("/discourse_media_indexer/media-db.json", {
      data: {
        limit: 100,
        offset: 0,
      },
    });
  },
});
