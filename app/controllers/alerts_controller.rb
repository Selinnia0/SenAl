class AlertsController < ApplicationController
  include LiveRefresh

  before_action :set_alert, only: %i[ show acknowledge resolve ]

  def index
    @status = params[:status].presence_in(Alert.statuses.keys + [ "all" ])
    @urgency = params[:urgency].presence_in(Alert.urgencies.keys)
    @query = params[:q].to_s.strip

    @alerts = Alert.includes(:service, :assignee).order(triggered_at: :desc)
    @alerts = case @status
    when nil then @alerts.not_resolved
    when "all" then @alerts
    else @alerts.where(status: @status)
    end
    @alerts = @alerts.where(urgency: @urgency) if @urgency
    if @query.present?
      @alerts = @alerts.where("LOWER(alerts.title) LIKE ?", "%#{Alert.sanitize_sql_like(@query.downcase)}%")
    end
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
      broadcast_refresh(@alert, :alerts)
      redirect_to @alert, notice: "Alarm güncellendi: #{helpers.enum_label(@alert, :status)}."
    rescue Alert::InvalidTransition => e
      redirect_to @alert, alert: e.message
    end
end
