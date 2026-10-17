class ScheduleMembership < ApplicationRecord
  belongs_to :schedule
  belongs_to :user

  validates :user_id, uniqueness: { scope: :schedule_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :schedule_id }
end
