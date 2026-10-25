class ServicesController < ApplicationController
  include ManagerOnly
  include LiveRefresh

  before_action :set_service, only: %i[ show edit update destroy test_alert ]

  def index
    @services = Service.includes(:escalation_policy).order(:name)
  end

  def show
  end

  def new
    @service = Service.new
  end

  def create
    @service = Service.new(service_params)

    if @service.save
      redirect_to @service, notice: "Servis oluşturuldu."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to @service, notice: "Servis güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @service.destroy
      redirect_to services_path, notice: "Servis silindi.", status: :see_other
    else
      redirect_to @service, alert: "Alarmı olan servis silinemez.", status: :see_other
    end
  end

  # Terminal açmadan alarm göndermek için. API (POST /api/v1/events) ile aynı EventIngestor'u kullanır:
  # tekilleştirme, aciliyet eşlemesi ve bildirim kuralları birebir aynı işler.
  def test_alert
    alert = params.expect(alert: %i[ summary severity dedup_key ])
    result = EventIngestor.new(@service).call(
      event_action: "trigger",
      dedup_key: alert[:dedup_key].presence || "deneme-#{SecureRandom.hex(3)}",
      summary: alert[:summary].to_s,
      severity: alert[:severity].presence
    )

    if result.http_status == :accepted
      broadcast_refresh(:alerts)
      status = result.body[:status] == "deduplicated" ? "Açık alarm zaten var; tekrar eden alarm olarak eklendi." : "Deneme alarmı gönderildi."
      redirect_to alert_path(result.body[:alert_id]), notice: status
    else
      redirect_to @service, alert: result.body[:error]
    end
  end

  private
    def set_service
      @service = Service.find(params[:id])
    end

    def service_params
      params.expect(service: %i[ name escalation_policy_id ack_reset_minutes ])
    end
end
