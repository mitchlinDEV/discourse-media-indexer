# frozen_string_literal: true

Discourse::Application.routes.append do
  # Existing JSON API endpoints (keep these as-is)
  namespace :discourse_media_indexer, defaults: { format: :json } do
    # Filesystem endpoint
    get "/list" => "media#index"          # /discourse_media_indexer/list

    # DB-backed endpoints
    get "/media-db" => "db_media#index"   # /discourse_media_indexer/media-db
    get "/media-db/:id" => "db_media#show"
  end

  # NEW: HTML route that boots the Ember app for the media grid UI
  # Visiting /media-browser will render the normal Discourse shell,
  # then the Ember route `mediaBrowser` will take over.
  get "/media-browser" => "list#latest"
end
