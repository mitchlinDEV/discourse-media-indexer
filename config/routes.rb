# frozen_string_literal: true

Discourse::Application.routes.append do
  namespace :discourse_media_indexer do
    # JSON endpoints (unchanged)
    get "/list" => "media#index",       defaults: { format: :json }
    get "/media-db" => "db_media#index", defaults: { format: :json }
    get "/media-db/:id" => "db_media#show", defaults: { format: :json }

    # HTML media browser page (grid of images)
    get "/media-browser" => "db_browser#index", defaults: { format: :html }
  end
end
