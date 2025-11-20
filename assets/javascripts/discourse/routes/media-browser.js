// assets/javascripts/discourse/routes/media-browser.js
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

const PAGE_SIZE = 100;

export default Route.extend({
  queryParams: {
    page: { refreshModel: true },
  },

  model(params) {
    const page = Number((params && params.page) || 1);
    const limit = PAGE_SIZE;
    const offset = (page - 1) * PAGE_SIZE;

    return ajax("/discourse_media_indexer/media-db.json", {
      data: { limit, offset },
    });
  },
});
