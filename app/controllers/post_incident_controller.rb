# Post-incident: çözülmüş olayların postmortem durumu ve açık takip görevleri.
class PostIncidentController < ApplicationController
  def index
    @incidents = Incident.where(status: %w[resolved closed]).includes(:service, :postmortem, :follow_ups, lead_assignment: :user)
                         .order(resolved_at: :desc)
    @open_follow_ups = FollowUp.open.includes(:owner, :incident).order(:due_on, :id)
  end
end
