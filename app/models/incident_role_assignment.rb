class IncidentRoleAssignment < ApplicationRecord
  belongs_to :incident
  belongs_to :user

  enum :role, { lead: 0, communications: 1 }, validate: true

  validates :role, uniqueness: { scope: :incident_id }
end
