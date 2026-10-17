require "test_helper"

# Z3: Bayatlamış "gördüm" → yeniden tetikleme. Servisin ack_reset_minutes'i 240 (4 saat).
class IncidentStaleTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice = users(:alice)
    @incident = Incident.trigger!(service: services(:sis), title: "Bayatlama testi", dedup_key: "stale-test", urgency: :high)
  end

  test "3 saat 59 dakikada acknowledged kalır; 4 saatte triggered olur ve seviye 0'a bildirim gider" do
    # Önce seviye 1'e eskale olsun ki retrigger!'ın seviyeyi sıfırladığı görülsün.
    travel 5.minutes
    Incident.escalate_due!
    @incident.reload.acknowledge!(by: users(:bob))
    assert_equal 1, @incident.current_level

    travel 3.hours + 59.minutes
    Incident.retrigger_stale!
    assert @incident.reload.acknowledged?

    travel 1.minute
    assert_difference -> { @alice.notifications.where(incident: @incident).count }, 1 do
      Incident.retrigger_stale!
    end
    @incident.reload

    assert @incident.triggered?
    assert_equal 0, @incident.current_level
    assert_equal 0, @incident.escalation_round
    assert_equal @alice, @incident.assignee
    assert_equal 5.minutes.from_now, @incident.escalate_at
    assert_equal %w[retriggered notified], @incident.incident_events.last(2).map(&:kind)
  end

  test "resolved olay hiçbir zaman yeniden tetiklenmez" do
    @incident.acknowledge!(by: @alice)
    @incident.resolve!(by: @alice)

    travel 30.days
    Incident.retrigger_stale!

    assert @incident.reload.resolved?
    assert_not_includes @incident.incident_events.map(&:kind), "retriggered"
  end

  test "stale_acknowledged servis bazlı süreyi kullanır" do
    fast = Service.create!(name: "Hızlı servis", escalation_policy: escalation_policies(:default), ack_reset_minutes: 30)
    quick = Incident.trigger!(service: fast, title: "Hızlı", dedup_key: "fast", urgency: :high)
    quick.acknowledge!(by: @alice)
    @incident.acknowledge!(by: @alice)

    travel 30.minutes

    assert_includes Incident.stale_acknowledged, quick
    assert_not_includes Incident.stale_acknowledged, @incident
  end
end
