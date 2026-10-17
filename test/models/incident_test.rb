require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @triggered = incidents(:triggered)
    @acknowledged = incidents(:acknowledged)
    @resolved = incidents(:resolved)
    @alice = users(:alice)
  end

  # --- İzinli geçişler (specs.md §4) ---

  test "triggered → acknowledged: acknowledge! durumu, zaman damgasını ve escalate_at'i günceller" do
    @triggered.acknowledge!(by: @alice)
    @triggered.reload

    assert @triggered.acknowledged?
    assert_equal Time.current, @triggered.acknowledged_at
    assert_nil @triggered.escalate_at
  end

  test "triggered → resolved: kullanıcı resolve! ile çözer" do
    @triggered.resolve!(by: @alice)
    @triggered.reload

    assert @triggered.resolved?
    assert_equal Time.current, @triggered.resolved_at
    assert_nil @triggered.escalate_at
  end

  test "triggered → resolved: API by: nil ile çözer" do
    @triggered.resolve!(by: nil)

    assert @triggered.reload.resolved?
    assert_nil @triggered.incident_events.last.user
  end

  test "acknowledged → resolved: resolve!" do
    @acknowledged.resolve!(by: @alice)
    @acknowledged.reload

    assert @acknowledged.resolved?
    assert_equal Time.current, @acknowledged.resolved_at
  end

  test "acknowledged → triggered: retrigger! seviyeyi ve turu sıfırlar" do
    @acknowledged.update!(current_level: 1, escalation_round: 1)

    @acknowledged.retrigger!
    @acknowledged.reload

    assert @acknowledged.triggered?
    assert_equal 0, @acknowledged.current_level
    assert_equal 0, @acknowledged.escalation_round
    assert_nil @acknowledged.acknowledged_at
  end

  # --- Yasak geçişler ---

  test "acknowledged → acknowledged yasak" do
    assert_raises(Incident::InvalidTransition) { @acknowledged.acknowledge!(by: @alice) }
    assert @acknowledged.reload.acknowledged?
  end

  test "triggered → triggered (retrigger!) yasak" do
    assert_raises(Incident::InvalidTransition) { @triggered.retrigger! }
    assert @triggered.reload.triggered?
  end

  test "resolved → acknowledged yasak" do
    assert_raises(Incident::InvalidTransition) { @resolved.acknowledge!(by: @alice) }
    assert @resolved.reload.resolved?
  end

  test "resolved → resolved yasak" do
    assert_raises(Incident::InvalidTransition) { @resolved.resolve!(by: @alice) }
    assert @resolved.reload.resolved?
  end

  test "resolved → triggered (retrigger!) yasak" do
    assert_raises(Incident::InvalidTransition) { @resolved.retrigger! }
    assert @resolved.reload.resolved?
  end

  test "yasak geçiş olay kaydı yazmaz" do
    assert_no_difference -> { IncidentEvent.count } do
      assert_raises(Incident::InvalidTransition) { @resolved.acknowledge!(by: @alice) }
    end
  end

  # --- Savunma katmanı: ham yollar ---

  test "resolved olayda update(status: :triggered) doğrulama hatasıyla başarısız olur" do
    assert_not @resolved.update(status: :triggered)
    assert @resolved.errors.of_kind?(:status, :invalid_transition)
    assert @resolved.reload.resolved?
  end

  test "resolved olayda enum'un ham triggered! metodu doğrulama hatasıyla başarısız olur" do
    assert_raises(ActiveRecord::RecordInvalid) { @resolved.triggered! }
    assert @resolved.reload.resolved?
  end

  test "resolved olayda enum'un ham acknowledged! metodu doğrulama hatasıyla başarısız olur" do
    assert_raises(ActiveRecord::RecordInvalid) { @resolved.acknowledged! }
    assert @resolved.reload.resolved?
  end

  test "durum değişmeyen güncellemeler engellenmez" do
    assert @resolved.update(title: "Yeni başlık")
  end

  # --- Zaman çizelgesi (IncidentEvent) ---

  test "acknowledge! acknowledged olayını kullanıcıyla yazar" do
    assert_difference -> { @triggered.incident_events.count }, 1 do
      @triggered.acknowledge!(by: @alice)
    end

    event = @triggered.incident_events.last
    assert_equal "acknowledged", event.kind
    assert_equal @alice, event.user
    assert_equal Time.current, event.occurred_at
  end

  test "resolve! resolved olayını yazar" do
    assert_difference -> { @acknowledged.incident_events.count }, 1 do
      @acknowledged.resolve!(by: @alice)
    end

    event = @acknowledged.incident_events.last
    assert_equal "resolved", event.kind
    assert_equal @alice, event.user
    assert_equal Time.current, event.occurred_at
  end

  test "retrigger! retriggered olayını sistem adına (user nil) yazar" do
    assert_difference -> { @acknowledged.incident_events.count }, 1 do
      @acknowledged.retrigger!
    end

    event = @acknowledged.incident_events.last
    assert_equal "retriggered", event.kind
    assert_nil event.user
    assert_equal Time.current, event.occurred_at
  end

  # --- UI için sorgu metotları ---

  test "can_acknowledge? ve can_resolve? izinli geçişleri yansıtır" do
    assert @triggered.can_acknowledge?
    assert @triggered.can_resolve?
    assert_not @acknowledged.can_acknowledge?
    assert @acknowledged.can_resolve?
    assert_not @resolved.can_acknowledge?
    assert_not @resolved.can_resolve?
  end
end
