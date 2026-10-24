require "test_helper"

# v2 response katmanı iş kuralları (revizyon §1.4).
class IncidentRulesTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
    @service = services(:sis)
  end

  # --- İlan etme ---

  test "olay lead olmadan ilan edilemez" do
    assert_no_difference -> { Incident.count } do
      error = assert_raises(ActiveRecord::RecordInvalid) { declare(lead: nil) }
      assert_match(/lider/i, error.message)
    end
  end

  test "ilan: triage, declared_at, lead ve 'ilan edildi' kaydı" do
    incident = declare(severity: :critical, communications: @bob)

    assert incident.triage?
    assert_equal Time.current, incident.declared_at
    assert_equal Time.current, incident.last_update_at
    assert_equal @alice, incident.lead
    assert_equal @bob, incident.communications_lead
    event = incident.timeline_events.sole
    assert_equal "status_change", event.kind
    assert_equal @manager, event.user
    assert_equal({ "from" => nil, "to" => "triage" }, event.details.slice("from", "to"))
  end

  test "alert'ten ilan edilince triggered alert ilan eden adına 'Gördüm' olur (eskalasyon durur)" do
    alert = alerts(:triggered)

    incident = declare(alert: alert)

    assert_equal alert, incident.alert
    alert.reload
    assert alert.acknowledged?
    assert_nil alert.escalate_at
    assert_equal @manager, alert.alert_events.last.user
  end

  test "zaten acknowledged alert'ten ilan etmek hata vermez, alert değişmez" do
    alert = alerts(:acknowledged)

    assert_no_changes -> { alert.reload.attributes } do
      declare(alert: alert)
    end
  end

  # --- public_impact ve durum sayfası ---

  test "public_impact olay, durum sayfası güncellemesi yayınlanmadan resolved olamaz" do
    incident = declare(public_impact: true)
    incident.transition_to!(:investigating, by: @alice)

    error = assert_raises(Incident::TransitionBlocked) { incident.transition_to!(:resolved, by: @alice) }
    assert_match(/durum sayfası/i, error.message)
    assert incident.reload.investigating?
  end

  test "TransitionBlocked bir InvalidTransition'dır" do
    assert_operator Incident::TransitionBlocked, :<, Incident::InvalidTransition
  end

  test "durum sayfası güncellemesi yayınlandıktan sonra resolved olur ve otomatik 'resolved' güncellemesi düşer" do
    incident = declare(public_impact: true)
    incident.transition_to!(:investigating, by: @alice)
    incident.publish_status_update!(public_status: :investigating, message: "Giriş sorununu inceliyoruz.", by: @bob)

    assert_difference -> { incident.status_page_updates.count }, 1 do
      incident.transition_to!(:resolved, by: @alice)
    end

    last = incident.status_page_updates.last
    assert last.public_resolved?
    assert_equal Time.current, last.published_at
    assert_predicate last.message, :present?
  end

  test "public olmayan olay resolved olunca durum sayfasına güncelleme düşmez" do
    incident = declare(public_impact: false)
    incident.transition_to!(:investigating, by: @alice)

    assert_no_difference -> { StatusPageUpdate.count } do
      incident.transition_to!(:resolved, by: @alice)
    end
  end

  test "durum sayfası güncellemesi yayınlamak zaman çizelgesine yazılır ve last_update_at'i günceller" do
    incident = declare(public_impact: true)
    travel 10.minutes

    incident.publish_status_update!(public_status: :identified, message: "Sorunu bulduk.", by: @bob)

    assert_equal Time.current, incident.reload.last_update_at
    assert incident.timeline_events.last.kind_update?
    assert_equal "identified", incident.timeline_events.last.details["status_page"]
  end

  test "olay çözülünce bağlı açık alert de çözülür" do
    alert = alerts(:triggered)
    incident = declare(alert: alert)
    incident.transition_to!(:investigating, by: @alice)

    incident.transition_to!(:resolved, by: @alice)

    assert alert.reload.resolved?
  end

  # --- Kapanış (closed) ---

  test "critical/major olay yayınlanmış postmortem olmadan kapanamaz" do
    incident = resolved_incident(severity: :major)

    error = assert_raises(Incident::TransitionBlocked) { incident.transition_to!(:closed, by: @alice) }
    assert_match(/postmortem/i, error.message)

    incident.create_postmortem!(body: "Taslak")
    assert_raises(Incident::TransitionBlocked) { incident.transition_to!(:closed, by: @alice) }

    incident.postmortem.publish!
    incident.transition_to!(:closed, by: @alice)
    assert incident.reload.closed?
  end

  test "minor olayda postmortem zorunlu değil" do
    incident = resolved_incident(severity: :minor)

    incident.transition_to!(:closed, by: @alice)

    assert incident.reload.closed?
  end

  test "tamamlanmamış takip görevi varken olay kapanamaz" do
    incident = resolved_incident(severity: :minor)
    follow_up = incident.follow_ups.create!(title: "Disk alarm eşiğini düşür", owner: @bob)

    error = assert_raises(Incident::TransitionBlocked) { incident.transition_to!(:closed, by: @alice) }
    assert_match(/takip/i, error.message)

    follow_up.complete!
    incident.transition_to!(:closed, by: @alice)
    assert incident.reload.closed?
  end

  test "olayı yalnızca lead veya yönetici kapatabilir" do
    incident = resolved_incident(severity: :minor)

    assert_raises(Incident::NotPermitted) { incident.transition_to!(:closed, by: @bob) }
    assert incident.reload.resolved?

    incident.transition_to!(:closed, by: @manager)
    assert incident.reload.closed?
  end

  # --- Güncellemeler, severity, roller ---

  test "güncelleme yazmak zaman çizelgesine 'update' ekler ve last_update_at'i günceller" do
    incident = declare
    travel 20.minutes

    incident.post_update!(body: "Veritabanı bağlantılarını yeniden başlatıyoruz.", by: @bob)

    assert_equal Time.current, incident.reload.last_update_at
    event = incident.timeline_events.last
    assert event.kind_update?
    assert_equal @bob, event.user
    assert_equal "Veritabanı bağlantılarını yeniden başlatıyoruz.", event.body
  end

  test "boş güncelleme yazılamaz" do
    incident = declare
    assert_raises(ActiveRecord::RecordInvalid) { incident.post_update!(body: "", by: @bob) }
  end

  test "kapanmış ya da reddedilmiş olaya güncelleme yazılamaz" do
    %i[closed_major declined_minor].each do |name|
      assert_raises(Incident::InvalidTransition) { incidents(name).post_update!(body: "Geç not", by: @bob) }
    end
  end

  test "severity değişikliği zaman çizelgesine yazılır; aynı değer kayıt yazmaz" do
    incident = declare(severity: :minor)

    incident.change_severity!(:critical, by: @bob)
    assert incident.reload.critical?
    event = incident.timeline_events.last
    assert event.kind_severity_change?
    assert_equal({ "from" => "minor", "to" => "critical" }, event.details.slice("from", "to"))

    assert_no_difference -> { incident.timeline_events.count } do
      assert_equal false, incident.change_severity!(:critical, by: @bob)
    end
  end

  test "rol ataması zaman çizelgesine yazılır; lead değiştirilebilir ama kaldırılamaz" do
    incident = declare

    incident.assign_role!(:communications, user: @bob, by: @manager)
    assert_equal @bob, incident.reload.communications_lead
    assert incident.timeline_events.last.kind_role_change?

    incident.assign_role!(:lead, user: @manager, by: @manager)
    assert_equal @manager, incident.reload.lead
    assert_equal 1, incident.role_assignments.where(role: :lead).count

    assert_raises(ActiveRecord::RecordInvalid) { incident.assign_role!(:lead, user: nil, by: @manager) }
    assert_equal @manager, incident.reload.lead
  end

  private
    def declare(lead: @alice, severity: :major, public_impact: false, alert: nil, communications: nil)
      Incident.declare!(service: @service, title: "Öğrenci girişi kapalı", summary: "SSO yanıt vermiyor",
                        severity: severity, public_impact: public_impact, lead: lead,
                        communications: communications, alert: alert, by: @manager)
    end

    def resolved_incident(severity:)
      declare(severity: severity).tap do |incident|
        incident.transition_to!(:investigating, by: @alice)
        incident.transition_to!(:resolved, by: @alice)
      end
    end
end
