# frozen_string_literal: true
Discourse::Application.routes.append do
  namespace :discourse_media_indexer, defaults: { format: :json } do
    get "/list" => "media#index"   # /discourse_media_indexer/list
  end
end
