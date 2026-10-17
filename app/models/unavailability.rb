class Unavailability < ApplicationRecord
  belongs_to :user

  # starts_at <= time < ends_at
  scope :covering, ->(time) { where(starts_at: ..time).where("unavailabilities.ends_at > ?", time) }

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_start

  private
    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, :after_start, message: "başlangıçtan sonra olmalı") unless ends_at > starts_at
    end
end
