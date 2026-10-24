class HomeController < ApplicationController
  def show
    now = Time.current
    @on_calls = Schedule.order(:name).map { |schedule| [ schedule, OnCall.for(schedule, at: now) ] }
    @open_alerts = Alert.not_resolved.includes(:service, :assignee).order(triggered_at: :desc)
    @gap_report = GapReport.new(from: now, to: now + 7.days)
  end
end
