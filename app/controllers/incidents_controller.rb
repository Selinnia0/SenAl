class IncidentsController < ApplicationController
  include IncidentScoped

  before_action :set_incident, only: %i[ show transition severity ]

  def index
    @status = params[:status].presence_in(Incident.statuses.keys + [ "all" ])
    @severity = params[:severity].presence_in(Incident.severities.keys)
    @query = params[:q].to_s.strip

    @incidents = Incident.includes(:service, lead_assignment: :user).order(declared_at: :desc)
    @incidents = case @status
    when nil then @incidents.active
    when "all" then @incidents
    else @incidents.where(status: @status)
    end
    @incidents = @incidents.where(severity: @severity) if @severity
    if @query.present?
      @incidents = @incidents.where("LOWER(incidents.title) LIKE ?", "%#{Incident.sanitize_sql_like(@query.downcase)}%")
    end
  end

  def show
    @users = User.order(:name)
  end

  def new
    alert = Alert.find_by(id: params[:alert_id])
    service = Service.find_by(id: params[:service_id] || alert&.service_id) || Service.order(:name).first
    @incident = Incident.new(service: service, alert: alert, title: alert&.title,
                             severity: (alert&.high? ? :critical : :major))
    load_form_options
  end

  def create
    attributes = params.expect(incident: %i[ service_id alert_id title summary severity lead_id communications_id public_impact ])
    @incident = Incident.declare!(
      service: Service.find(attributes[:service_id]), alert: Alert.find_by(id: attributes[:alert_id]),
      title: attributes[:title], summary: attributes[:summary], severity: attributes[:severity],
      public_impact: ActiveModel::Type::Boolean.new.cast(attributes[:public_impact]) || false,
      lead: User.find_by(id: attributes[:lead_id]), communications: User.find_by(id: attributes[:communications_id]),
      by: Current.user
    )
    broadcast_incident_change
    redirect_to @incident, notice: "Olay ilan edildi: #{helpers.incident_ref(@incident)}."
  rescue ActiveRecord::RecordInvalid => error
    @incident = error.record.is_a?(Incident) ? error.record : Incident.new(attributes.slice(:service_id, :title, :summary))
    @incident.errors.merge!(error.record.errors) unless error.record.is_a?(Incident)
    @selected_lead_id = attributes[:lead_id]
    load_form_options
    render :new, status: :unprocessable_entity
  end

  def transition
    to = params[:to].to_s
    run_incident_action("Durum: #{helpers.t("enums.incident.status.#{to}", default: to)}.") do
      @incident.transition_to!(to, by: Current.user)
    end
  end

  def severity
    run_incident_action("Önem güncellendi.") { @incident.change_severity!(params[:severity], by: Current.user) }
  end

  private
    def load_form_options
      @services = Service.order(:name)
      @users = User.order(:name)
      @suggested_lead = @incident.service && Incident.suggested_lead(@incident.service)
      @selected_lead_id ||= @suggested_lead&.id
    end
end
