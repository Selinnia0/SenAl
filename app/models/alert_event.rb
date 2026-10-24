class AlertEvent < ApplicationRecord
  KINDS = %w[
    triggered notified acknowledged resolved escalated
    retriggered deduplicated gap_skipped escalation_exhausted
  ].freeze

  belongs_to :alert
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :occurred_at, presence: true
end
