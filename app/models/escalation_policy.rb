class EscalationPolicy < ApplicationRecord
  has_many :escalation_levels, -> { order(:position) }, dependent: :destroy, inverse_of: :escalation_policy
  has_many :services, dependent: :restrict_with_error

  validates :name, presence: true
  validates :repeat_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
