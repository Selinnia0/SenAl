class FollowUpsController < ApplicationController
  include IncidentScoped

  before_action :set_incident

  def create
    run_incident_action("Takip görevi eklendi.") do
      @incident.follow_ups.create!(params.expect(follow_up: %i[ title owner_id due_on ]))
    end
  end

  def complete
    run_incident_action("Takip görevi tamamlandı.") { @incident.follow_ups.find(params[:id]).complete! }
  end
end
