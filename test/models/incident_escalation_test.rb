require "test_helper"

# Z1: "Gördüm" zaman aşımı → eskalasyon.
# Fixture politikası: seviye 0 = BT Altyapı (nöbetçi Ayşe), seviye 1 = Laboratuvar (nöbetçi Burak),
# her seviye 5 dk, repeat_count 1.
class IncidentEscalationTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
  end

  test "4 dakika sonra eskale olmaz; 5 dakika sonra seviye 1'e geçer ve seviye 1 nöbetçisine bildirim gider" do
    incident = trigger(:high)

    travel 4.minutes
    Incident.escalate_due!
    incident.reload
    assert_equal 0, incident.current_level
    assert_equal [ @alice ], incident.notifications.map(&:user)

    travel 1.minute
    Incident.escalate_due!
    incident.reload
    assert_equal 1, incident.current_level
    assert_equal [ @alice, @bob ], incident.notifications.order(:id).map(&:user)
    assert_equal @bob, incident.assignee
    assert_equal 5.minutes.from_now, incident.escalate_at
    assert_equal %w[triggered notified escalated notified], incident.incident_events.map(&:kind)
  end

  test "son seviyede zaman aşımı → repeat_count kadar baştan döner; sonra escalation_exhausted" do
    incident = trigger(:high)

    [ [ 1, 0, @bob ], [ 0, 1, @alice ], [ 1, 1, @bob ] ].each do |level, round, on_call|
      travel 5.minutes
      Incident.escalate_due!
      incident.reload
      assert_equal [ level, round ], [ incident.current_level, incident.escalation_round ]
      assert_equal on_call, incident.assignee
    end

    travel 5.minutes
    assert_difference -> { @manager.notifications.where(incident: incident).count }, 1 do
      Incident.escalate_due!
    end
    incident.reload
    assert_nil incident.escalate_at
    assert incident.triggered?
    assert_equal "escalation_exhausted", incident.incident_events.last.kind

    travel 30.minutes
    assert_no_difference -> { incident.incident_events.count } do
      Incident.escalate_due!
    end
  end

  test "acknowledged olay zaman aşımında eskale olmaz" do
    incident = trigger(:high)
    incident.acknowledge!(by: @alice)

    travel 10.minutes
    Incident.escalate_due!
    incident.reload

    assert incident.acknowledged?
    assert_equal 0, incident.current_level
    assert_not_includes incident.incident_events.map(&:kind), "escalated"
  end

  test "low aciliyetli olay hiç eskale olmaz" do
    incident = trigger(:low)

    6.times do
      travel 5.minutes
      Incident.escalate_due!
    end
    incident.reload

    assert_equal 0, incident.current_level
    assert_nil incident.escalate_at
    assert_equal [ @alice ], incident.notifications.map(&:user)
    assert_not_includes incident.incident_events.map(&:kind), "escalated"
  end

  test "seviye 0'da boşluk varsa olay tetiklenir tetiklenmez seviye 1 nöbetçisine gider" do
    schedules(:primary).schedule_memberships.destroy_all

    incident = trigger(:high)

    assert_equal 1, incident.current_level
    assert_equal @bob, incident.assignee
    assert_equal [ @bob ], incident.notifications.map(&:user)
    assert_equal 5.minutes.from_now, incident.escalate_at
    assert_equal %w[triggered gap_skipped escalated notified], incident.incident_events.map(&:kind)
  end

  # --- Ek durumlar ---

  test "tüm seviyelerde boşluk varsa turlar beklemeden tükenir ve yöneticiye bildirim gider" do
    schedules(:primary).schedule_memberships.destroy_all
    schedules(:secondary).schedule_memberships.destroy_all

    incident = trigger(:high)

    assert_nil incident.escalate_at
    assert_equal "escalation_exhausted", incident.incident_events.last.kind
    assert_equal 4, incident.incident_events.where(kind: "gap_skipped").count
    assert_equal [ @manager ], incident.notifications.map(&:user)
  end

  test "escalation_due yalnızca zamanı gelmiş triggered olayları seçer" do
    due = trigger(:high, key: "due")
    trigger(:low, key: "low")
    acknowledged = trigger(:high, key: "ack").tap { |i| i.acknowledge!(by: @alice) }

    travel 5.minutes

    assert_includes Incident.escalation_due, due
    assert_not_includes Incident.escalation_due, acknowledged
    assert Incident.escalation_due.all?(&:high?)
  end

  test "escalate! triggered olmayan olayda hiçbir şey yapmaz" do
    incident = incidents(:acknowledged)

    assert_no_difference -> { incident.incident_events.count } do
      assert_equal false, incident.escalate!
    end
  end

  private
    def trigger(urgency, key: "esc-test")
      Incident.trigger!(service: services(:sis), title: "Eskalasyon testi", dedup_key: key, urgency: urgency)
    end
end
