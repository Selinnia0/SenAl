class SchedulesController < ApplicationController
  include ScheduleCalendar

  def index
    @schedules = Schedule.order(:name).includes(:members)
  end

  def show
    @schedule = Schedule.find(params[:id])
    @override = Override.new(schedule: @schedule)
    load_schedule_calendar
  end
end
