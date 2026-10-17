require "test_helper"

class EventsApiTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @service = services(:sis)
  end

  # --- specs.md §6 zorunlu testler ---

  test "geçersiz anahtar 401" do
    assert_no_difference -> { Incident.count } do
      post_event event_action: "trigger", dedup_key: "x", summary: "y", key: "yanlis-anahtar"
    end
    assert_response :unauthorized
  end

  test "trigger yeni olay açar" do
    assert_difference -> { Incident.count }, 1 do
      post_event event_action: "trigger", dedup_key: "cpu-high-web1", summary: "web1 CPU %99", severity: "critical"
    end

    assert_response :accepted
    incident = Incident.find(response.parsed_body["incident_id"])
    assert_equal({ "status" => "triggered", "incident_id" => incident.id, "dedup_key" => "cpu-high-web1" }, response.parsed_body)
    assert incident.triggered?
    assert incident.high?
    assert_equal "web1 CPU %99", incident.title
    assert_equal @service, incident.service
    assert_equal Time.current, incident.triggered_at
  end

  test "aynı dedup_key ile ikinci trigger olay açmaz" do
    open_incident = incidents(:triggered)

    assert_no_difference -> { Incident.count } do
      post_event event_action: "trigger", dedup_key: open_incident.dedup_key, summary: "db1 disk %97"
    end

    assert_response :accepted
    assert_equal "deduplicated", response.parsed_body["status"]
    assert_equal open_incident.id, response.parsed_body["incident_id"]
    assert_equal "deduplicated", open_incident.incident_events.last.kind
  end

  test "resolve olayı kapatır" do
    incident = incidents(:triggered)

    post_event event_action: "resolve", dedup_key: incident.dedup_key

    assert_response :accepted
    assert_equal "resolved", response.parsed_body["status"]
    assert incident.reload.resolved?
    assert_nil incident.incident_events.last.user
  end

  test "bozuk gövde 422" do
    [
      "bu json değil",
      { event_action: "trigger", dedup_key: "x" }.to_json,         # summary yok
      { event_action: "patlat", dedup_key: "x" }.to_json,          # bilinmeyen eylem
      { event_action: "resolve" }.to_json,                         # dedup_key yok
      { event_action: "trigger", dedup_key: "", summary: "y" }.to_json,
      [ 1, 2 ].to_json
    ].each do |body|
      assert_no_difference -> { Incident.count } do
        post api_v1_events_path, params: body, headers: auth_headers.merge("Content-Type" => "application/json")
      end
      assert_response :unprocessable_entity, "Gövde: #{body}"
      assert response.parsed_body["error"].present?
    end
  end

  # --- Ek durumlar ---

  test "çözülmüş olayın dedup_key'i ile trigger yeni olay açar" do
    assert_difference -> { Incident.count }, 1 do
      post_event event_action: "trigger", dedup_key: incidents(:resolved).dedup_key, summary: "Sertifika yine"
    end
    assert_equal "triggered", response.parsed_body["status"]
  end

  test "acknowledge açık olayı üstlenir" do
    incident = incidents(:triggered)

    post_event event_action: "acknowledge", dedup_key: incident.dedup_key

    assert_response :accepted
    assert_equal "acknowledged", response.parsed_body["status"]
    assert incident.reload.acknowledged?
  end

  test "açık olayı olmayan dedup_key için acknowledge/resolve 404" do
    %w[acknowledge resolve].each do |action|
      post_event event_action: action, dedup_key: "olmayan-anahtar"
      assert_response :not_found
    end
  end

  test "izin verilmeyen geçiş 409" do
    post_event event_action: "acknowledge", dedup_key: incidents(:acknowledged).dedup_key
    assert_response :conflict
  end

  test "trigger seviye 0 nöbetçisine bildirim gönderir, assignee atar ve escalate_at ayarlar" do
    assert_difference -> { users(:alice).notifications.count }, 1 do
      post_event event_action: "trigger", dedup_key: "disk-full-db2", summary: "db2 disk %95", severity: "error"
    end

    incident = Incident.find(response.parsed_body["incident_id"])
    assert_equal users(:alice), incident.assignee
    assert_equal 5.minutes.from_now, incident.escalate_at
    assert_equal %w[triggered notified], incident.incident_events.map(&:kind)
    assert_equal users(:alice).id, incident.incident_events.last.details["user_id"]
  end

  test "severity warning, info veya yoksa low; low olayda escalate_at nil ama bildirim gider" do
    [ "warning", "info", nil ].each_with_index do |severity, i|
      post_event(**{ event_action: "trigger", dedup_key: "low-#{i}", summary: "Uyarı", severity: severity }.compact)

      incident = Incident.find(response.parsed_body["incident_id"])
      assert incident.low?, "severity: #{severity.inspect}"
      assert_nil incident.escalate_at
      assert_equal users(:alice), incident.assignee
    end
  end

  test "bilinmeyen severity 422" do
    post_event event_action: "trigger", dedup_key: "x", summary: "y", severity: "felaket"
    assert_response :unprocessable_entity
  end

  private
    def post_event(key: @service.integration_key, **payload)
      post api_v1_events_path, params: payload.to_json,
                               headers: auth_headers(key).merge("Content-Type" => "application/json")
    end

    def auth_headers(key = @service.integration_key)
      { "Authorization" => "Token token=#{key}" }
    end
end
