require "test_helper"

class IncidentsControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
    sign_in_as @bob
  end

  # --- Liste ---

  test "liste: eyebrow, serif başlık, filtre pill'leri, tablo; canlı akışa abone" do
    get incidents_path
    assert_response :success
    assert_select ".eyebrow"
    assert_select "h1", "Olaylar"
    assert_select ".filters a.filter-pill", minimum: 5
    assert_select "table.table td", text: incidents(:triage_critical).title
    assert_select "turbo-cable-stream-source"
  end

  test "liste severity ve durum filtresi" do
    get incidents_path(severity: "critical")
    assert_select "td", text: incidents(:triage_critical).title
    assert_select "td", text: incidents(:investigating_major).title, count: 0

    get incidents_path(status: "investigating")
    assert_select "td", text: incidents(:investigating_major).title
    assert_select "td", text: incidents(:triage_critical).title, count: 0
  end

  test "liste varsayılan olarak aktifleri gösterir; 'tümü' kapanmışları da" do
    get incidents_path
    assert_select "td", text: incidents(:closed_major).title, count: 0
    get incidents_path(status: "all")
    assert_select "td", text: incidents(:closed_major).title
  end

  test "arama başlıkta arar" do
    get incidents_path(q: "ders kaydı", status: "all")
    assert_select "td", text: incidents(:investigating_major).title
    assert_select "td", text: incidents(:triage_critical).title, count: 0
  end

  test "boş liste: empty state" do
    Incident.update_all(status: Incident.statuses[:closed])
    get incidents_path
    assert_select ".empty-state .empty-state__message", "Şu an her şey yolunda."
  end

  # --- İlan etme ---

  test "ilan formu önerilen lead'i (Z6) seçili getirir" do
    get new_incident_path(service_id: services(:sis).id)
    assert_response :success
    assert_select "select[name='incident[lead_id]'] option[selected][value=?]", @alice.id.to_s
    assert_select ".field__hint", /önerilen/i
  end

  test "alert'ten ilan: başlık ve servis dolu gelir" do
    alert = alerts(:triggered)
    get new_incident_path(alert_id: alert.id)
    assert_select "input[name='incident[title]'][value=?]", alert.title
    assert_select "input[type=hidden][name='incident[alert_id]'][value=?]", alert.id.to_s
  end

  test "ilan eder ve olay sayfasına gider" do
    assert_difference -> { Incident.count }, 1 do
      post incidents_path, params: { incident: { service_id: services(:sis).id, title: "Kütüphane sistemi kapalı",
                                                 summary: "Katalog açılmıyor", severity: "major", lead_id: @alice.id,
                                                 public_impact: "1" } }
    end
    incident = Incident.order(:id).last
    assert_redirected_to incident_path(incident)
    assert_equal @alice, incident.lead
    assert incident.public_impact?
    assert_equal @bob, incident.timeline_events.first.user
  end

  test "lead'siz ilan 422" do
    assert_no_difference -> { Incident.count } do
      post incidents_path, params: { incident: { service_id: services(:sis).id, title: "Lidersiz", severity: "minor", lead_id: "" } }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors", /lider/i
  end

  test "alert'ten ilan edilince alert 'Gördüm' olur" do
    alert = alerts(:triggered)
    post incidents_path, params: { incident: { service_id: alert.service_id, alert_id: alert.id, title: alert.title,
                                               severity: "critical", lead_id: @alice.id } }
    assert alert.reload.acknowledged?
  end

  # --- Detay ---

  test "detay: 2/3 + 1/3 ızgara, rozetler, zaman çizelgesi, güncelleme formu, roller kartı" do
    incident = incidents(:investigating_major)
    get incident_path(incident)

    assert_select ".detail-grid"
    assert_select "h1", incident.title
    assert_select ".badge--major"
    assert_select ".badge--info", text: "İnceleniyor"
    assert_select "form[action=?] textarea", incident_updates_path(incident)
    assert_select ".roles", /Ayşe Kaya/
    assert_select "turbo-cable-stream-source"
  end

  test "detay: yalnızca izinli geçiş butonları görünür" do
    get incident_path(incidents(:triage_critical))
    assert_select ".transitions button", 2
    assert_select ".transitions button", text: "İncelemeye al"
    assert_select ".transitions button", text: "Reddet (yanlış alarm)"

    get incident_path(incidents(:closed_major))
    assert_select ".transitions button", count: 0

    get incident_path(incidents(:resolved_major))
    assert_select ".transitions button", text: "Yeniden aç"
    assert_select ".transitions button", text: "Kapat"
  end

  test "Z3 bandı: güncelleme gecikince başlığın altında görünür" do
    incident = incidents(:triage_critical) # son güncelleme 09:50, critical
    get incident_path(incident)
    assert_select ".banner", count: 0

    travel 21.minutes
    get incident_path(incident)
    assert_select ".banner", /güncelleme gecikti/i
  end

  test "Z4 bandı: postmortem gecikince görünür" do
    incident = incidents(:resolved_major) # 2026-10-18 11:00'de çözüldü
    travel 5.days
    get incident_path(incident)
    assert_select ".banner", /postmortem gecikti/i
  end

  # --- Geçiş ve severity ---

  test "geçiş yapar, zaman çizelgesine yazar ve canlı yenileme yayınlar" do
    incident = incidents(:triage_critical)

    assert_turbo_stream_broadcasts incident do
      post transition_incident_path(incident), params: { to: "investigating" }
    end
    assert_redirected_to incident_path(incident)
    assert incident.reload.investigating?
  end

  test "engellenen geçiş hata mesajıyla geri döner" do
    incident = incidents(:triage_critical)
    incident.update!(status: :investigating)

    post transition_incident_path(incident), params: { to: "resolved" } # public, durum sayfası güncellemesi yok
    assert_redirected_to incident_path(incident)
    follow_redirect!
    assert_select "[role=alert]", /durum sayfası/i
    assert incident.reload.investigating?
  end

  test "yetkisiz kapatma reddedilir" do
    incident = incidents(:resolved_major)
    incident.update!(severity: :minor)

    post transition_incident_path(incident), params: { to: "closed" }
    follow_redirect!
    assert_select "[role=alert]", /yalnızca olay lideri/i
    assert incident.reload.resolved?
  end

  test "severity değiştirir" do
    incident = incidents(:investigating_major)
    patch severity_incident_path(incident), params: { severity: "critical" }
    assert incident.reload.critical?
  end

  # --- Alert sayfasından ilan ---

  test "alert detayında 'Olay ilan et' bağlantısı" do
    alert = alerts(:triggered)
    get alert_path(alert)
    assert_select "a[href=?]", new_incident_path(alert_id: alert.id), text: "Olay ilan et"
  end

  test "üst bardaki 'Olay ilan et' çalışır, arama olaylarda arar" do
    get dashboard_path
    assert_select "header.topbar a.btn--accent[href=?]", new_incident_path
    assert_select "header.topbar form[action=?] input[name=q]", incidents_path
  end
end
