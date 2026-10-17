class IncidentsController < ApplicationController
  before_action :set_incident, only: %i[ show acknowledge resolve ]

  def index
    @status = params[:status].presence_in(Incident.statuses.keys)
    @incidents = Incident.includes(:service, :assignee).order(triggered_at: :desc)
    @incidents = @incidents.where(status: @status) if @status
  end

  def show
  end

  def acknowledge
    transition { @incident.acknowledge!(by: Current.user) }
  end

  def resolve
    transition { @incident.resolve!(by: Current.user) }
  end

  private
    def set_incident
      @incident = Incident.find(params[:id])
    end

    def transition
      yield
      redirect_to @incident, notice: "Olay güncellendi: #{helpers.enum_label(@incident, :status)}."
    rescue Incident::InvalidTransition => e
      redirect_to @incident, alert: e.message
    end
end
