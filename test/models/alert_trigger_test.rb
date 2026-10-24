require "test_helper"

class AlertTriggerTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @service = services(:sis)
  end

  test "trigger! olayı açar, triggered ve notified kayıtlarını yazar" do
    alert = Alert.trigger!(service: @service, title: "Test", dedup_key: "t1", urgency: :high)

    assert alert.triggered?
    assert_equal Time.current, alert.triggered_at
    assert_equal %w[triggered notified], alert.alert_events.map(&:kind)
    assert_equal [ users(:alice) ], alert.notifications.map(&:user)
    assert_equal users(:alice), alert.assignee
    assert_equal 5.minutes.from_now, alert.escalate_at
  end

  test "low aciliyette bildirim gider ama escalate_at nil" do
    alert = Alert.trigger!(service: @service, title: "Test", dedup_key: "t1", urgency: :low)

    assert_equal [ users(:alice) ], alert.notifications.map(&:user)
    assert_nil alert.escalate_at
  end

  test "politikada seviye yoksa bildirim gitmez ve escalate_at nil" do
    policy = EscalationPolicy.create!(name: "Seviyesiz")
    service = Service.create!(name: "Seviyesiz servis", escalation_policy: policy)

    alert = Alert.trigger!(service: service, title: "Test", dedup_key: "t1", urgency: :high)

    assert_empty alert.notifications
    assert_nil alert.assignee
    assert_nil alert.escalate_at
    assert_equal %w[triggered], alert.alert_events.map(&:kind)
  end

  test "aynı servis ve dedup_key ile ikinci açık olay geçersiz" do
    duplicate = Alert.new(service: @service, title: "Kopya", dedup_key: alerts(:triggered).dedup_key,
                             urgency: :high, triggered_at: Time.current)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:dedup_key, :taken)
  end

  test "çözülmüş olayla aynı dedup_key'e sahip yeni olay geçerli" do
    alert = Alert.new(service: @service, title: "Yeni", dedup_key: alerts(:resolved).dedup_key,
                            urgency: :low, triggered_at: Time.current)

    assert alert.valid?
  end
end
