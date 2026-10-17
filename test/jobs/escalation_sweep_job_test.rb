require "test_helper"

class EscalationSweepJobTest < ActiveJob::TestCase
  test "eskalasyonu ve bayatlamayı tetikler (smoke)" do
    travel_to Time.zone.parse("2026-10-19 10:00")
    triggered = incidents(:triggered)     # escalate_at 10:05
    acknowledged = incidents(:acknowledged) # acknowledged_at 09:02, 4 saat sonra bayat

    travel_to Time.zone.parse("2026-10-19 13:02")
    EscalationSweepJob.perform_now

    assert_equal 1, triggered.reload.current_level
    assert acknowledged.reload.triggered?
  end
end
