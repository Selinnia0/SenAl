class OverridesController < ApplicationController
  include ScheduleCalendar

  before_action :set_schedule

  def create
    @override = @schedule.overrides.build(override_params)

    if @override.save
      redirect_to @schedule, notice: "Elle değişiklik eklendi."
    else
      load_schedule_calendar
      render "schedules/show", status: :unprocessable_entity
    end
  end

  def destroy
    if Current.user.manager?
      @schedule.overrides.find(params[:id]).destroy!
      redirect_to @schedule, notice: "Elle değişiklik silindi.", status: :see_other
    else
      redirect_to @schedule, alert: "Elle değişikliği yalnızca yöneticiler silebilir.", status: :see_other
    end
  end

  private
    def set_schedule
      @schedule = Schedule.find(params[:schedule_id])
    end

    def override_params
      params.expect(override: %i[ user_id starts_at ends_at ])
    end
end
