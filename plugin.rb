# frozen_string_literal: true
# name: discourse-media-indexer
# about: List media from a mounted path for tagging/publishing
# version: 0.0.1
# authors: mitchlinDEV
# url: https://github.com/mitchlinDEV/discourse-media-indexer
# required_version: 3.0.0

enabled_site_setting :media_index_enabled

after_initialize do
  module ::DiscourseMediaIndexer; end

  class ::DiscourseMediaIndexer::Engine < ::Rails::Engine
    engine_name "discourse_media_indexer"
    isolate_namespace DiscourseMediaIndexer
  end

  # load plugin routes so /discourse_media_indexer/list works
  load File.expand_path("../config/routes.rb", __FILE__)
  # Ensure media indexer scheduled job is loaded
  load File.expand_path("app/jobs/scheduled/media_indexer_scan.rb", __dir__)
end
