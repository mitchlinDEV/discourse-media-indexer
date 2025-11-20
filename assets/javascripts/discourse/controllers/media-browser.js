// assets/javascripts/discourse/controllers/media-browser.js
import Controller from "@ember/controller";
import { computed } from "@ember/object";

export default Controller.extend({
  queryParams: ["page"],
  page: 1,

  // Always return an array; avoids any undefined issues
  media: computed("model.media.[]", function () {
    const model = this.model || {};
    return model.media || [];
  }),

  actions: {
    nextPage() {
      const current = this.page || 1;
      this.set("page", current + 1);
    },

    prevPage() {
      const current = this.page || 1;
      if (current > 1) {
        this.set("page", current - 1);
      }
    },
  },
});
