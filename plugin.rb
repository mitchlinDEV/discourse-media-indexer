# frozen_string_literal: true
# name: discourse-media-indexer
# about: List media from a mounted path for tagging/publishing
# version: 0.0.1
# authors: mitchlinDEV
# url: https://github.com/mitchlinDEV/discourse-media-indexer
# required_version: 3.0.0

gem 'mini_exiftool', '~> 2.11', require: false

enabled_site_setting :media_indexer_enabled

after_initialize do
  # Ensure models and job are loaded
  %w[
    app/models/discourse_media_indexer/media_file.rb
    app/models/discourse_media_indexer/tag.rb
    app/models/discourse_media_indexer/file_tag.rb
    app/controllers/discourse_media_indexer/media_controller.rb
    app/jobs/scheduled/media_indexer_scan.rb
  ].each do |rel|
    load File.expand_path(rel, __dir__)
  end
end
