# frozen_string_literal: true
module DiscourseMediaIndexer
  class MediaController < ::ApplicationController
    requires_plugin "discourse-media-indexer"

    before_action :ensure_logged_in
    before_action :ensure_staff

    def index
      raise Discourse::InvalidParameters.new(:limit) if limit < 1 || limit > 2000

      root = SiteSetting.media_indexer_root_path
      exts = SiteSetting.media_indexer_extensions.split("|").map { |e| ".#{e.downcase}" }

      list = []
      require "find"
      Find.find(root) do |p|
        next unless File.file?(p)
        next unless exts.include?(File.extname(p).downcase)
        stat = File.stat(p) rescue nil
        next unless stat
        list << {
          path: p.sub(/^#{Regexp.escape(root)}/, ""),
          size: stat.size,
          mtime: stat.mtime.utc.iso8601,
          ext: File.extname(p).downcase.delete(".")
        }
        break if list.length >= limit
      end

      render_json_dump({
        root: root,
        count: list.length,
        items: list
      })
    end

    private

    def limit
      (params[:limit] || 500).to_i
    end
  end
end
