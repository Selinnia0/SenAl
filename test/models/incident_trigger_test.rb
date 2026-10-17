require "test_helper"

class IncidentTriggerTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @service = services(:sis)
  end

  test "trigger! olayı açar, triggered ve notified kayıtlarını yazar" do
    incident = Incident.trigger!(service: @service, title: "Test", dedup_key: "t1", urgency: :high)

    assert incident.triggered?
    assert_equal Time.current, incident.triggered_at
    assert_equal %w[triggered notified], incident.incident_events.map(&:kind)
    assert_equal [ users(:alice) ], incident.notifications.map(&:user)
    assert_equal users(:alice), incident.assignee
    assert_equal 5.minutes.from_now, incident.escalate_at
  end

  test "low aciliyette bildirim gider ama escalate_at nil" do
    incident = Incident.trigger!(service: @service, title: "Test", dedup_key: "t1", urgency: :low)

    assert_equal [ users(:alice) ], incident.notifications.map(&:user)
    assert_nil incident.escalate_at
  end

  test "politikada seviye yoksa bildirim gitmez ve escalate_at nil" do
    policy = EscalationPolicy.create!(name: "Seviyesiz")
    service = Service.create!(name: "Seviyesiz servis", escalation_policy: policy)

    incident = Incident.trigger!(service: service, title: "Test", dedup_key: "t1", urgency: :high)

    assert_empty incident.notifications
    assert_nil incident.assignee
    assert_nil incident.escalate_at
    assert_equal %w[triggered], incident.incident_events.map(&:kind)
  end

  test "aynı servis ve dedup_key ile ikinci açık olay geçersiz" do
    duplicate = Incident.new(service: @service, title: "Kopya", dedup_key: incidents(:triggered).dedup_key,
                             urgency: :high, triggered_at: Time.current)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:dedup_key, :taken)
  end

  test "çözülmüş olayla aynı dedup_key'e sahip yeni olay geçerli" do
    incident = Incident.new(service: @service, title: "Yeni", dedup_key: incidents(:resolved).dedup_key,
                            urgency: :low, triggered_at: Time.current)

    assert incident.valid?
  end
end
