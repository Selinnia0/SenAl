class ServicesController < ApplicationController
  include ManagerOnly

  before_action :set_service, only: %i[ show edit update destroy ]

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
      redirect_to @service, alert: "Olayı olan servis silinemez.", status: :see_other
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
