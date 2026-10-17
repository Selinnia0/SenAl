class EscalationLevel < ApplicationRecord
  belongs_to :escalation_policy
  belongs_to :schedule

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :escalation_policy_id }
  validates :timeout_minutes, numericality: { only_integer: true, greater_than: 0 }
end
