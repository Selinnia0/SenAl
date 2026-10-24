# Olayın (response katmanı) zaman çizelgesi. "update" ActiveRecord#update! ile çakıştığı için önekli:
# kind_update?, TimelineEvent.kind_update.
class TimelineEvent < ApplicationRecord
  belongs_to :incident
  belongs_to :user, optional: true

  enum :kind, { update: 0, status_change: 1, role_change: 2, severity_change: 3, reopened: 4 },
       prefix: true, validate: true

  validates :occurred_at, presence: true
  validates :body, presence: true, if: :kind_update?
end
