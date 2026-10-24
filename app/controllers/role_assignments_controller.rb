class RoleAssignmentsController < ApplicationController
  include IncidentScoped

  before_action :set_incident

  def create
    role = params[:role].presence_in(IncidentRoleAssignment.roles.keys)
    return redirect_to @incident, alert: "Bilinmeyen rol." unless role

    run_incident_action("Rol atandı.") do
      @incident.assign_role!(role, user: User.find_by(id: params[:user_id]), by: Current.user)
    end
  end
end
