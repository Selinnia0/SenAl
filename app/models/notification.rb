class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :incident, optional: true # boşluk raporu (Z5) olaya bağlı değil

  scope :unread, -> { where(read_at: nil) }

  validates :message, presence: true, unless: :incident
end
