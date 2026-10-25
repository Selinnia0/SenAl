# Demo aracı: eskalasyonu beklemeden görmek için açık alarmları ileri sarar. Yalnızca manager,
# yalnızca özellik açıkken (bkz. TimeSkip.enabled?).
class TimeSkipsController < ApplicationController
  include ManagerOnly
  include LiveRefresh

  # Özellik kapalıyken sayfanın varlığı da belli olmasın: kimlik/yetki kontrolünden önce 404.
  prepend_before_action :require_enabled

  PRESETS = [ 1, 5, 10, 30, 60, 240, 24 * 60, 5 * 24 * 60 ].freeze

  def new
    @time_skip = TimeSkip.new(minutes: 5)
    load_open_alerts
  end

  def create
    @time_skip = TimeSkip.new(minutes: params.expect(time_skip: [ :minutes ])[:minutes])

    if @time_skip.valid?
      summary = @time_skip.run!
      broadcast_refresh(:alerts, :incidents)
      redirect_to new_time_skip_path, notice: "#{@time_skip.minutes} dakika ileri sarıldı. #{describe(summary)}"
    else
      load_open_alerts
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_enabled
      head :not_found unless TimeSkip.enabled?
    end

    def load_open_alerts
      @open_alerts = Alert.not_resolved.includes(:service, :assignee).order(triggered_at: :desc)
      @active_incidents = Incident.active.includes(:service, lead_assignment: :user).order(declared_at: :desc)
    end

    def describe(summary)
      return "Zamanı gelen eskalasyon veya bayatlama olmadı." if summary.empty?

      summary.map { |kind, count| "#{t("time_skip.summary.#{kind}", default: t("enums.alert_event.kind.#{kind}", default: kind))}: #{count}" }.join(", ") + "."
    end
end
