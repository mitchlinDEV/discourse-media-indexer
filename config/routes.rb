# frozen_string_literal: true

Discourse::Application.routes.append do
  # JSON API endpoints (existing)
  namespace :discourse_media_indexer, defaults: { format: :json } do
    get "/list" => "media#index"          # /discourse_media_indexer/list
    get "/media-db" => "db_media#index"   # /discourse_media_indexer/media-db
    get "/media-db/:id" => "db_media#show"
  end

  # HTML media browser page (server-rendered)
  get "/media-browser" => "discourse_media_indexer/db_browser#index"
end
