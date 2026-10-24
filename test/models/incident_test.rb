require "test_helper"

# v2 response katmanı durum makinesi:
#   triage → investigating → fixing → monitoring → resolved → closed
#   triage → declined (yanlış alarm)
#   ileri atlama: investigating → monitoring | resolved, fixing → resolved
#   geri dönüş (reopen): monitoring → investigating, resolved → investigating
class IncidentTest < ActiveSupport::TestCase
  ALLOWED = {
    "triage" => %w[investigating declined],
    "investigating" => %w[fixing monitoring resolved],
    "fixing" => %w[monitoring resolved],
    "monitoring" => %w[resolved investigating],
    "resolved" => %w[closed investigating],
    "closed" => [],
    "declined" => []
  }.freeze

  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
  end

  # --- İzinli geçişler: her kenar ---

  ALLOWED.each do |from, targets|
    targets.each do |to|
      test "#{from} → #{to} izinli ve zaman çizelgesine yazılır" do
        incident = incident_in(from)

        assert_difference -> { incident.timeline_events.count }, 1 do
          incident.transition_to!(to, by: @alice)
        end

        assert_equal to, incident.reload.status
        event = incident.timeline_events.last
        assert_equal @alice, event.user
        assert_equal({ "from" => from, "to" => to }, event.details.slice("from", "to"))
        assert_equal Time.current, event.occurred_at
      end
    end
  end

  # --- Spec'te sayılan yasaklar: her biri ayrı test ---

  Incident.statuses.each_key do |to|
    test "closed → #{to} yasak" do
      assert_forbidden incident_in("closed"), to
    end

    test "declined → #{to} yasak" do
      assert_forbidden incident_in("declined"), to
    end
  end

  test "resolved → triage yasak" do
    assert_forbidden incident_in("resolved"), "triage"
  end

  test "triage → closed yasak" do
    assert_forbidden incident_in("triage"), "closed"
  end

  test "monitoring → triage yasak" do
    assert_forbidden incident_in("monitoring"), "triage"
  end

  # --- İzin listesinde olmayan her çift yasak (kapsamlı) ---

  test "izin listesinde olmayan bütün geçişler InvalidTransition fırlatır" do
    Incident.statuses.each_key do |from|
      Incident.statuses.each_key do |to|
        next if ALLOWED.fetch(from).include?(to)

        assert_forbidden incident_in(from), to
      end
    end
  end

  test "Incident::ALLOWED_TRANSITIONS testteki tabloyla aynı" do
    assert_equal ALLOWED, Incident::ALLOWED_TRANSITIONS
  end

  # --- Geri dönüş (reopen) ---

  test "resolved → investigating yeniden açar: reopened kaydı, resolved_at temizlenir" do
    incident = incident_in("resolved")

    incident.transition_to!(:investigating, by: @bob)
    incident.reload

    assert incident.investigating?
    assert_nil incident.resolved_at
    assert_equal "reopened", incident.timeline_events.last.kind
  end

  test "monitoring → investigating reopened kaydı yazar" do
    incident = incident_in("monitoring")

    incident.transition_to!(:investigating, by: @bob)

    assert_equal "reopened", incident.timeline_events.last.kind
  end

  test "ileri geçiş status_change kaydı yazar" do
    incident = incident_in("triage")
    incident.transition_to!(:investigating, by: @bob)
    assert_equal "status_change", incident.timeline_events.last.kind
  end

  # --- Zaman damgaları ---

  test "resolved ve closed zaman damgaları ayarlanır; her geçiş last_update_at'i günceller" do
    incident = incident_in("monitoring", severity: :minor)

    incident.transition_to!(:resolved, by: @alice)
    assert_equal Time.current, incident.reload.resolved_at
    assert_equal Time.current, incident.last_update_at

    travel 1.hour
    incident.transition_to!(:closed, by: @alice)
    assert_equal Time.current, incident.reload.closed_at
  end

  # --- Savunma katmanı: enum bang metotları ve ham update ---

  test "closed olayda enum'un ham investigating! metodu doğrulama hatasıyla başarısız olur" do
    incident = incident_in("closed")
    assert_raises(ActiveRecord::RecordInvalid) { incident.investigating! }
    assert incident.reload.closed?
  end

  test "declined olayda update(status: :triage) başarısız olur" do
    incident = incident_in("declined")
    assert_not incident.update(status: :triage)
    assert incident.errors.of_kind?(:status, :invalid_transition)
    assert incident.reload.declined?
  end

  test "triage olayda enum'un ham closed! metodu başarısız olur" do
    incident = incident_in("triage")
    assert_raises(ActiveRecord::RecordInvalid) { incident.closed! }
    assert incident.reload.triage?
  end

  test "can_transition_to? izin listesini yansıtır" do
    assert incident_in("triage").can_transition_to?(:investigating)
    assert_not incident_in("triage").can_transition_to?(:closed)
    assert_equal %w[fixing monitoring resolved], incident_in("investigating").available_transitions
  end

  private
    # İstenen durumda, kapanış ön koşulları sağlanmış (minor, public değil, takip görevi yok) olay.
    def incident_in(status, severity: :minor)
      incident = Incident.new(service: services(:sis), title: "#{status} olayı", severity: severity,
                              status: status, declared_at: 1.hour.ago, last_update_at: 1.hour.ago,
                              resolved_at: (1.hour.ago if %w[resolved closed].include?(status)),
                              closed_at: (1.hour.ago if status == "closed"))
      incident.build_lead_assignment(user: @alice)
      incident.save!
      incident
    end

    def assert_forbidden(incident, to)
      from = incident.status
      assert_no_difference -> { incident.timeline_events.count }, "#{from} → #{to}" do
        assert_raises(Incident::InvalidTransition, "#{from} → #{to}") { incident.transition_to!(to, by: @manager) }
      end
      assert_equal from, incident.reload.status
    end
end
