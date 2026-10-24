require "test_helper"

class EscalationSweepJobTest < ActiveJob::TestCase
  test "eskalasyonu ve bayatlamayı tetikler (smoke)" do
    travel_to Time.zone.parse("2026-10-19 10:00")
    triggered = alerts(:triggered)     # escalate_at 10:05
    acknowledged = alerts(:acknowledged) # acknowledged_at 09:02, 4 saat sonra bayat

    travel_to Time.zone.parse("2026-10-19 13:02")
    EscalationSweepJob.perform_now

    assert_equal 1, triggered.reload.current_level
    assert acknowledged.reload.triggered?
  end

  test "olay hatırlatıcılarını da çalıştırır (smoke)" do
    travel_to Time.zone.parse("2026-10-19 10:00")
    incident = Incident.declare!(service: services(:sis), title: "Hatırlatıcı", severity: :critical,
                                 lead: users(:alice), by: users(:manager))

    travel 30.minutes
    assert_difference -> { incident.notifications.count }, 1 do
      EscalationSweepJob.perform_now
    end
  end
end
