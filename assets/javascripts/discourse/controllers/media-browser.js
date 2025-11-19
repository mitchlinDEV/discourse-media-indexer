// assets/javascripts/discourse/controllers/media-browser.js
import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class MediaBrowserController extends Controller {
  // query-params
  queryParams = ["page"];

  @tracked page = 1;

  get media() {
    // model is whatever the route's model() returns
    return this.model?.media || [];
  }

  @action
  nextPage() {
    this.page = (this.page || 1) + 1;
  }

  @action
  prevPage() {
    const current = this.page || 1;
    if (current > 1) {
      this.page = current - 1;
    }
  }
}
