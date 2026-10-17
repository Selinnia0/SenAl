# Takvim detay sayfasının verileri (SchedulesController#show ve hatalı override formu).
module ScheduleCalendar
  CALENDAR_DAYS = 14

  private
    def load_schedule_calendar
      @memberships = @schedule.schedule_memberships.includes(:user)
      @days = @schedule.on_call_days(from_date: Date.current, days: CALENDAR_DAYS)
      @overrides = @schedule.overrides.where(ends_at: Time.current..).includes(:user).order(:starts_at)
      @users = User.order(:name)
    end
end
