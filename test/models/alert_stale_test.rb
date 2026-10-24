require "test_helper"

# Z3: Bayatlamış "gördüm" → yeniden tetikleme. Servisin ack_reset_minutes'i 240 (4 saat).
class AlertStaleTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice = users(:alice)
    @alert = Alert.trigger!(service: services(:sis), title: "Bayatlama testi", dedup_key: "stale-test", urgency: :high)
  end

  test "3 saat 59 dakikada acknowledged kalır; 4 saatte triggered olur ve seviye 0'a bildirim gider" do
    # Önce seviye 1'e eskale olsun ki retrigger!'ın seviyeyi sıfırladığı görülsün.
    travel 5.minutes
    Alert.escalate_due!
    @alert.reload.acknowledge!(by: users(:bob))
    assert_equal 1, @alert.current_level

    travel 3.hours + 59.minutes
    Alert.retrigger_stale!
    assert @alert.reload.acknowledged?

    travel 1.minute
    assert_difference -> { @alice.notifications.where(alert: @alert).count }, 1 do
      Alert.retrigger_stale!
    end
    @alert.reload

    assert @alert.triggered?
    assert_equal 0, @alert.current_level
    assert_equal 0, @alert.escalation_round
    assert_equal @alice, @alert.assignee
    assert_equal 5.minutes.from_now, @alert.escalate_at
    assert_equal %w[retriggered notified], @alert.alert_events.last(2).map(&:kind)
  end

  test "resolved olay hiçbir zaman yeniden tetiklenmez" do
    @alert.acknowledge!(by: @alice)
    @alert.resolve!(by: @alice)

    travel 30.days
    Alert.retrigger_stale!

    assert @alert.reload.resolved?
    assert_not_includes @alert.alert_events.map(&:kind), "retriggered"
  end

  test "stale_acknowledged servis bazlı süreyi kullanır" do
    fast = Service.create!(name: "Hızlı servis", escalation_policy: escalation_policies(:default), ack_reset_minutes: 30)
    quick = Alert.trigger!(service: fast, title: "Hızlı", dedup_key: "fast", urgency: :high)
    quick.acknowledge!(by: @alice)
    @alert.acknowledge!(by: @alice)

    travel 30.minutes

    assert_includes Alert.stale_acknowledged, quick
    assert_not_includes Alert.stale_acknowledged, @alert
  end
end
