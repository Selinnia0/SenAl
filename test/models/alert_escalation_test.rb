require "test_helper"

# Z1: "Gördüm" zaman aşımı → eskalasyon.
# Fixture politikası: seviye 0 = BT Altyapı (nöbetçi Ayşe), seviye 1 = Laboratuvar (nöbetçi Burak),
# her seviye 5 dk, repeat_count 1.
class AlertEscalationTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
  end

  test "4 dakika sonra eskale olmaz; 5 dakika sonra seviye 1'e geçer ve seviye 1 nöbetçisine bildirim gider" do
    alert = trigger(:high)

    travel 4.minutes
    Alert.escalate_due!
    alert.reload
    assert_equal 0, alert.current_level
    assert_equal [ @alice ], alert.notifications.map(&:user)

    travel 1.minute
    Alert.escalate_due!
    alert.reload
    assert_equal 1, alert.current_level
    assert_equal [ @alice, @bob ], alert.notifications.order(:id).map(&:user)
    assert_equal @bob, alert.assignee
    assert_equal 5.minutes.from_now, alert.escalate_at
    assert_equal %w[triggered notified escalated notified], alert.alert_events.map(&:kind)
  end

  test "son seviyede zaman aşımı → repeat_count kadar baştan döner; sonra escalation_exhausted" do
    alert = trigger(:high)

    [ [ 1, 0, @bob ], [ 0, 1, @alice ], [ 1, 1, @bob ] ].each do |level, round, on_call|
      travel 5.minutes
      Alert.escalate_due!
      alert.reload
      assert_equal [ level, round ], [ alert.current_level, alert.escalation_round ]
      assert_equal on_call, alert.assignee
    end

    travel 5.minutes
    assert_difference -> { @manager.notifications.where(alert: alert).count }, 1 do
      Alert.escalate_due!
    end
    alert.reload
    assert_nil alert.escalate_at
    assert alert.triggered?
    assert_equal "escalation_exhausted", alert.alert_events.last.kind

    travel 30.minutes
    assert_no_difference -> { alert.alert_events.count } do
      Alert.escalate_due!
    end
  end

  test "acknowledged olay zaman aşımında eskale olmaz" do
    alert = trigger(:high)
    alert.acknowledge!(by: @alice)

    travel 10.minutes
    Alert.escalate_due!
    alert.reload

    assert alert.acknowledged?
    assert_equal 0, alert.current_level
    assert_not_includes alert.alert_events.map(&:kind), "escalated"
  end

  test "low aciliyetli olay hiç eskale olmaz" do
    alert = trigger(:low)

    6.times do
      travel 5.minutes
      Alert.escalate_due!
    end
    alert.reload

    assert_equal 0, alert.current_level
    assert_nil alert.escalate_at
    assert_equal [ @alice ], alert.notifications.map(&:user)
    assert_not_includes alert.alert_events.map(&:kind), "escalated"
  end

  test "seviye 0'da boşluk varsa olay tetiklenir tetiklenmez seviye 1 nöbetçisine gider" do
    schedules(:primary).schedule_memberships.destroy_all

    alert = trigger(:high)

    assert_equal 1, alert.current_level
    assert_equal @bob, alert.assignee
    assert_equal [ @bob ], alert.notifications.map(&:user)
    assert_equal 5.minutes.from_now, alert.escalate_at
    assert_equal %w[triggered gap_skipped escalated notified], alert.alert_events.map(&:kind)
  end

  # --- Ek durumlar ---

  test "tüm seviyelerde boşluk varsa turlar beklemeden tükenir ve yöneticiye bildirim gider" do
    schedules(:primary).schedule_memberships.destroy_all
    schedules(:secondary).schedule_memberships.destroy_all

    alert = trigger(:high)

    assert_nil alert.escalate_at
    assert_equal "escalation_exhausted", alert.alert_events.last.kind
    assert_equal 4, alert.alert_events.where(kind: "gap_skipped").count
    assert_equal [ @manager ], alert.notifications.map(&:user)
  end

  test "escalation_due yalnızca zamanı gelmiş triggered olayları seçer" do
    due = trigger(:high, key: "due")
    trigger(:low, key: "low")
    acknowledged = trigger(:high, key: "ack").tap { |i| i.acknowledge!(by: @alice) }

    travel 5.minutes

    assert_includes Alert.escalation_due, due
    assert_not_includes Alert.escalation_due, acknowledged
    assert Alert.escalation_due.all?(&:high?)
  end

  test "escalate! triggered olmayan olayda hiçbir şey yapmaz" do
    alert = alerts(:acknowledged)

    assert_no_difference -> { alert.alert_events.count } do
      assert_equal false, alert.escalate!
    end
  end

  private
    def trigger(urgency, key: "esc-test")
      Alert.trigger!(service: services(:sis), title: "Eskalasyon testi", dedup_key: key, urgency: urgency)
    end
end
