class AlertsController < ApplicationController
  before_action :set_alert, only: %i[ show acknowledge resolve ]

  def index
    @status = params[:status].presence_in(Alert.statuses.keys)
    @alerts = Alert.includes(:service, :assignee).order(triggered_at: :desc)
    @alerts = @alerts.where(status: @status) if @status
  end

  def show
  end

  def acknowledge
    transition { @alert.acknowledge!(by: Current.user) }
  end

  def resolve
    transition { @alert.resolve!(by: Current.user) }
  end

  private
    def set_alert
      @alert = Alert.find(params[:id])
    end

    def transition
      yield
      redirect_to @alert, notice: "Alarm güncellendi: #{helpers.enum_label(@alert, :status)}."
    rescue Alert::InvalidTransition => e
      redirect_to @alert, alert: e.message
    end
end
