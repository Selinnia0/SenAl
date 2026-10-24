# Zaman çizelgesine güncelleme. Turbo Stream isteğinde toast + zaman çizelgesi + boş form döner.
class IncidentUpdatesController < ApplicationController
  include IncidentScoped

  before_action :set_incident

  def create
    if params[:body].blank?
      return redirect_to @incident, alert: "Güncelleme boş olamaz."
    end

    @incident.post_update!(body: params[:body], by: Current.user)
    broadcast_incident_change

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("toasts", partial: "components/toast", locals: { type: "notice", message: "Güncelleme yayınlandı." }),
          turbo_stream.replace("timeline", partial: "incidents/timeline", locals: { incident: @incident }),
          turbo_stream.replace("update_form", partial: "incidents/update_form", locals: { incident: @incident }),
          turbo_stream.replace("incident_banners", partial: "incidents/banners", locals: { incident: @incident })
        ]
      end
      format.html { redirect_to @incident, notice: "Güncelleme yayınlandı." }
    end
  rescue *IncidentScoped::DOMAIN_ERRORS => error
    redirect_to @incident, alert: domain_error_message(error)
  end
end
