require "test_helper"

class GapReportJobTest < ActiveJob::TestCase
  test "boşluk raporunu çalıştırır (smoke)" do
    travel_to Time.zone.parse("2026-10-19 10:00")
    BlackoutPeriod.create!(name: "Bayram", kind: :holiday, applies_to: :everyone,
                           starts_on: Date.new(2026, 10, 21), ends_on: Date.new(2026, 10, 21))

    assert_difference -> { users(:manager).notifications.count }, 1 do
      GapReportJob.perform_now
    end
  end
end
