class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :incident

  scope :unread, -> { where(read_at: nil) }
end
