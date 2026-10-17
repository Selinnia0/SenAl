class Schedule < ApplicationRecord
  has_many :schedule_memberships, -> { order(:position) }, dependent: :destroy, inverse_of: :schedule
  has_many :members, through: :schedule_memberships, source: :user
  has_many :overrides, dependent: :destroy
  has_many :escalation_levels, dependent: :restrict_with_error

  validates :name, :starts_at, presence: true
  validates :rotation_days, numericality: { only_integer: true, greater_than: 0 }
end
