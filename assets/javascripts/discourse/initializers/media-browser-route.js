// assets/javascripts/discourse/initializers/media-browser-route.js
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "media-browser-route",

  initialize() {
    withPluginApi("0.8.7", (api) => {
      // Adds a SPA route:
      //   name: mediaBrowser
      //   path: /media-browser
      api.addRoute("mediaBrowser", "/media-browser");
    });
  },
};
