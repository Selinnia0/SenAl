require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  test "manager olmayan kullanıcı servis sayfalarına erişemez" do
    sign_in_as users(:alice)
    service = services(:sis)

    get services_path
    assert_redirected_to root_path
    get service_path(service)
    assert_redirected_to root_path
    get new_service_path
    assert_redirected_to root_path

    assert_no_difference -> { Service.count } do
      post services_path, params: { service: { name: "Sinsi", escalation_policy_id: escalation_policies(:default).id } }
    end
    assert_redirected_to root_path

    delete service_path(service)
    assert Service.exists?(service.id)
  end

  test "manager servis oluşturur, entegrasyon anahtarı üretilir" do
    sign_in_as users(:manager)

    assert_difference -> { Service.count }, 1 do
      post services_path, params: { service: { name: "Kütüphane", escalation_policy_id: escalation_policies(:default).id } }
    end
    service = Service.find_by!(name: "Kütüphane")
    assert_redirected_to service_path(service)
    assert_predicate service.integration_key, :present?
  end

  test "servis detayı integration_key ve kopyalanabilir curl örneği gösterir" do
    sign_in_as users(:manager)
    service = services(:sis)

    get service_path(service)
    assert_response :success
    assert_select "code", text: service.integration_key
    assert_select "pre", /curl -X POST .*\/api\/v1\/events/m
    assert_select "pre", /Token token=#{service.integration_key}/
    assert_select "button", text: "Kopyala"
  end

  test "geçersiz servis formu 422 döner" do
    sign_in_as users(:manager)
    post services_path, params: { service: { name: "", escalation_policy_id: escalation_policies(:default).id } }
    assert_response :unprocessable_entity
  end
end

class ServiceTestAlertTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @service = services(:sis)
  end

  test "manager arayüzden deneme alarmı gönderir; API ile aynı yoldan olay açılır" do
    sign_in_as users(:manager)

    assert_difference -> { Incident.count }, 1 do
      post test_alert_service_path(@service), params: { alert: { summary: "Arayüzden deneme", severity: "critical", dedup_key: "" } }
    end

    incident = Incident.order(:id).last
    assert_redirected_to incident_path(incident)
    assert incident.triggered?
    assert incident.high?
    assert_equal "Arayüzden deneme", incident.title
    assert_equal users(:alice), incident.assignee
    assert_equal %w[triggered notified], incident.incident_events.map(&:kind)
  end

  test "aynı dedup_key ile ikinci deneme alarmı yeni olay açmaz" do
    sign_in_as users(:manager)
    open_incident = incidents(:triggered)

    assert_no_difference -> { Incident.count } do
      post test_alert_service_path(@service), params: { alert: { summary: "Tekrar", severity: "critical", dedup_key: open_incident.dedup_key } }
    end
    assert_redirected_to incident_path(open_incident)
    assert_equal "deduplicated", open_incident.incident_events.last.kind
  end

  test "başlıksız deneme alarmı reddedilir" do
    sign_in_as users(:manager)

    assert_no_difference -> { Incident.count } do
      post test_alert_service_path(@service), params: { alert: { summary: "", severity: "critical" } }
    end
    assert_redirected_to service_path(@service)
    follow_redirect!
    assert_select "[role=alert]", /Geçersiz olay gövdesi/
  end

  test "manager olmayan kullanıcı deneme alarmı gönderemez" do
    sign_in_as users(:alice)

    assert_no_difference -> { Incident.count } do
      post test_alert_service_path(@service), params: { alert: { summary: "Sinsi", severity: "critical" } }
    end
    assert_redirected_to root_path
  end

  test "servis sayfasında deneme alarmı formu var" do
    sign_in_as users(:manager)
    get service_path(@service)
    assert_select "form[action=?]", test_alert_service_path(@service)
  end
end
