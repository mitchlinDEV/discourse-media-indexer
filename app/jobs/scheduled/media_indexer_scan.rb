# frozen_string_literal: true

# Simple scheduled job for the media indexer.
#
# This version does NOT yet do heavy indexing work – it only logs that it ran,
# so we can confirm that:
#   - the job is registered
#   - Sidekiq sees it
#   - it shows up in the Discourse scheduler UI.
#
# Once this is visible and running we can plug in the real scanning logic.

module ::DiscourseMediaIndexer
  class Scanner
    def self.run
      Rails.logger.info("[MediaIndexer] Scanner job executed at #{Time.zone.now}")
    end
  end
end

class ::Jobs::MediaIndexerScan < ::Jobs::Scheduled
  # How often to run – adjust later if you like
  every 1.hour

  def execute(args)
    ::DiscourseMediaIndexer::Scanner.run
  end
end
