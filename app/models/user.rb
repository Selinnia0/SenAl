class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :schedule_memberships, dependent: :destroy
  has_many :schedules, through: :schedule_memberships
  has_many :overrides, dependent: :destroy

  enum :role, { responder: 0, manager: 1 }, validate: true
  enum :academic_role, { staff: 0, assistant: 1 }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  # Z4 (Faz 5): izin ve akademik takvim kontrolü buraya gelecek.
  def available_at?(time)
    true
  end
end
