class StatusPageUpdatesController < ApplicationController
  include IncidentScoped

  before_action :set_incident

  def create
    run_incident_action("Durum sayfası güncellendi.") do
      @incident.publish_status_update!(public_status: params[:public_status], message: params[:message], by: Current.user)
    end
  end
end
