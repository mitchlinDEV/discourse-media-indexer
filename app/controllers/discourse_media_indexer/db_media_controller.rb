# frozen_string_literal: true

module DiscourseMediaIndexer
  class DbMediaController < ::ApplicationController
    requires_plugin DiscourseMediaIndexer::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_staff

    def index
      raise Discourse::NotFound unless SiteSetting.media_indexer_enabled

      media = base_relation

      media = filter_by_kind(media)
      media = filter_by_extension(media)
      media = filter_by_folder(media)
      media = filter_by_tags(media)
      media = filter_by_query(media)

      media = media.order(created_at: :desc)

      page     = (params[:page] || 1).to_i
      per_page = effective_limit
      offset   = (page - 1) * per_page

      total = media.count
      media = media.offset(offset).limit(per_page)

      render_json_dump(
        media: serialize_data(media, DiscourseMediaIndexer::MediaFileSerializer),
        meta: {
          total: total,
          page: page,
          per_page: per_page,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    def show
      raise Discourse::NotFound unless SiteSetting.media_indexer_enabled

      media = DiscourseMediaIndexer::MediaFile.find_by(id: params[:id])
      raise Discourse::NotFound if media.nil?

      render_json_dump(
        media: serialize_data(media, DiscourseMediaIndexer::MediaFileSerializer)
      )
    end

    private

    # Base scope with eager loading
    def base_relation
      DiscourseMediaIndexer::MediaFile
        .includes(:tags)
        .where.not(path: nil)
    end

    # kind=image,video or kind=image
    def filter_by_kind(relation)
      return relation if params[:kind].blank?

      kinds = params[:kind].to_s.split(",").map(&:strip).reject(&:blank?)
      return relation if kinds.empty?

      relation.where(kind: kinds)
    end

    # ext=jpg,png,webm
    def filter_by_extension(relation)
      return relation if params[:ext].blank?

      exts = params[:ext].to_s.split(",").map { |e| e.downcase.strip }.reject(&:blank?)
      return relation if exts.empty?

      relation.where(extension: exts)
    end

    # folder=images,videos
    # Uses folder column if present; otherwise derives from path.
    def filter_by_folder(relation)
      return relation if params[:folder].blank?

      folders = params[:folder].to_s.split(",").map(&:strip).reject(&:blank?)
      return relation if folders.empty?

      if relation.column_names.include?("folder")
        relation.where(folder: folders)
      else
        # Path-based folder: first segment before "/"
        conditions = folders.map { |_| "path LIKE ?" }
        values     = folders.map { |f| "#{f}/%" }

        relation.where(conditions.join(" OR "), *values)
      end
    end

    # tags=foo,bar
    def filter_by_tags(relation)
      return relation if params[:tags].blank?

      tag_names = params[:tags].to_s.split(",").map(&:strip).reject(&:blank?)
      return relation if tag_names.empty?

      relation
        .joins(:tags)
        .where(discourse_media_indexer_tags: { name: tag_names })
        .distinct
    end

    # q=substring (filename/path)
    def filter_by_query(relation)
      return relation if params[:q].blank?

      q = "%#{params[:q].to_s.downcase}%"
      relation.where(
        "LOWER(filename) LIKE :q OR LOWER(path) LIKE :q",
        q: q,
      )
    end

    # Reuse the idea of limit with a safe cap
    def effective_limit
      raw =
        if params[:per_page].present?
          params[:per_page]
        else
          params[:limit] || 500
        end

      value = raw.to_i
      value = 1    if value < 1
      value = 2000 if value > 2000
      value
    end
  end
end
