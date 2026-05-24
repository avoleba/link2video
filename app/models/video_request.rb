# frozen_string_literal: true

class VideoRequest < ActiveRecord::Base
  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }
  enum :platform, { youtube: 0, instagram: 1, tiktok: 2, unknown: 3 }

  validates :url, presence: true

  # scope :completed, -> { where(status: STATUSES[:completed]) }
  # scope :processing, -> { where(status: STATUSES[:processing]) }
  # scope :failed, -> { where(status: STATUSES[:failed]) }
end
