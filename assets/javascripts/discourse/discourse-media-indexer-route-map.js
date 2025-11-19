// assets/javascripts/discourse/discourse-media-indexer-route-map.js
export default {
  resource: "discovery",
  path: "/",
  map() {
    // URL: /media-browser
    this.route("media-browser");
  },
};
