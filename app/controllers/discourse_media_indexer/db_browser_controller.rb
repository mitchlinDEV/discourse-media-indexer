# frozen_string_literal: true

module DiscourseMediaIndexer
  class DbBrowserController < ::ApplicationController
    requires_plugin "discourse-media-indexer"

    def index
      limit  = (params[:limit] || 100).to_i
      offset = (params[:offset] || 0).to_i

      @media =
        MediaFile
          .order("id ASC")
          .limit(limit)
          .offset(offset)

      render :index
    end
  end
end
