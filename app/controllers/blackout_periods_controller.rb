# Akademik takvim: sınav haftası, bayram, dönem arası. Yalnızca manager.
class BlackoutPeriodsController < ApplicationController
  include ManagerOnly

  before_action :set_blackout_period, only: %i[ edit update destroy ]

  def index
    @blackout_periods = BlackoutPeriod.order(starts_on: :desc)
  end

  def new
    @blackout_period = BlackoutPeriod.new(starts_on: Date.current, ends_on: Date.current)
  end

  def create
    @blackout_period = BlackoutPeriod.new(blackout_period_params)

    if @blackout_period.save
      redirect_to blackout_periods_path, notice: "Akademik kapanma dönemi eklendi."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @blackout_period.update(blackout_period_params)
      redirect_to blackout_periods_path, notice: "Akademik kapanma dönemi güncellendi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blackout_period.destroy!
    redirect_to blackout_periods_path, notice: "Akademik kapanma dönemi silindi.", status: :see_other
  end

  private
    def set_blackout_period
      @blackout_period = BlackoutPeriod.find(params[:id])
    end

    def blackout_period_params
      params.expect(blackout_period: %i[ name kind applies_to starts_on ends_on ])
    end
end
