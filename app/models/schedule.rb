class Schedule < ApplicationRecord
  has_many :escalation_levels, dependent: :restrict_with_error

  validates :name, :starts_at, presence: true
  validates :rotation_days, numericality: { only_integer: true, greater_than: 0 }
end
