# Akademik kapanma dönemi. Tarihler iki uç dahil, Istanbul gün sınırlarına göre.
class BlackoutPeriod < ApplicationRecord
  enum :kind, { exam_week: 0, holiday: 1, semester_break: 2 }, validate: true
  enum :applies_to, { assistants: 0, everyone: 1 }, validate: true

  scope :on_date, ->(date) { where(starts_on: ..date, ends_on: date..) }
  scope :applying_to, ->(user) { user.assistant? ? all : everyone }

  validates :name, :starts_on, :ends_on, presence: true
  validate :ends_on_or_after_start

  private
    def ends_on_or_after_start
      return if starts_on.blank? || ends_on.blank?

      errors.add(:ends_on, :before_start, message: "başlangıçtan önce olamaz") if ends_on < starts_on
    end
end
