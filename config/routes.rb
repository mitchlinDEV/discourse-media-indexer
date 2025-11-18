# frozen_string_literal: true
Discourse::Application.routes.append do
  namespace :discourse_media_indexer, defaults: { format: :json } do
    # Your existing filesystem endpoint:
    get "/list" => "media#index"    # /discourse_media_indexer/list

    # New DB-backed endpoints (correct controller reference):
    get "/media-db" => "db_media#index"
    get "/media-db/:id" => "db_media#show"
  end
end
