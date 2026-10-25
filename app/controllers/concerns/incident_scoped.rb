# Olay detayındaki eylemler için ortak davranış: olayı yükler, domain hatalarını kullanıcı mesajına çevirir
# ve canlı yenilemeyi açıkça yayınlar (callback değil; yasak listesi).
module IncidentScoped
  extend ActiveSupport::Concern
  include LiveRefresh

  DOMAIN_ERRORS = [ Incident::InvalidTransition, Incident::NotPermitted, ActiveRecord::RecordInvalid ].freeze

  private
    def set_incident
      @incident = Incident.find(params[:incident_id] || params[:id])
    end

    # Olayı ve listeyi (pano dahil) izleyen herkese yenileme.
    def broadcast_incident_change(incident = @incident)
      broadcast_refresh(incident, :incidents)
    end

    # Domain işlemini çalıştırır; başarılıysa yayınlar ve olay sayfasına döner, hata mesajı flash olur.
    def run_incident_action(notice)
      yield
      broadcast_incident_change
      redirect_to @incident, notice: notice
    rescue *DOMAIN_ERRORS => error
      redirect_to @incident, alert: domain_error_message(error)
    end

    def domain_error_message(error)
      error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
    end
end
