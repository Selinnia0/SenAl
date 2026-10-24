class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :schedule_memberships, dependent: :destroy
  has_many :schedules, through: :schedule_memberships
  has_many :overrides, dependent: :destroy
  has_many :unavailabilities, dependent: :destroy

  enum :role, { responder: 0, manager: 1 }, validate: true
  enum :academic_role, { staff: 0, assistant: 1 }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  # Z6: kişisel izin veya kişiye uygulanan akademik kapanma dönemi varsa müsait değil.
  # Kişi bir kez izin girer, tüm takvimlerden otomatik düşer (OnCall bunu kullanır).
  def available_at?(time)
    return false if unavailabilities.covering(time).exists?

    BlackoutPeriod.applying_to(self).on_date(time.in_time_zone.to_date).none?
  end
end
