# Müsaitliğim: kullanıcı yalnızca kendi izinlerini görür, ekler ve siler.
class UnavailabilitiesController < ApplicationController
  def index
    @unavailability = Unavailability.new
    load_unavailabilities
  end

  def create
    @unavailability = Current.user.unavailabilities.build(unavailability_params)

    if @unavailability.save
      redirect_to unavailabilities_path, notice: "İzin eklendi; tüm nöbet takvimlerinde otomatik atlanacaksınız."
    else
      load_unavailabilities
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.unavailabilities.find(params[:id]).destroy!
    redirect_to unavailabilities_path, notice: "İzin silindi.", status: :see_other
  end

  private
    def unavailability_params
      params.expect(unavailability: %i[ starts_at ends_at reason ])
    end

    def load_unavailabilities
      @unavailabilities = Current.user.unavailabilities.order(:starts_at)
      @blackout_periods = BlackoutPeriod.applying_to(Current.user).where(ends_on: Date.current..).order(:starts_on)
    end
end
