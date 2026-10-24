require "test_helper"

class EventsApiTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @service = services(:sis)
  end

  # --- specs.md §6 zorunlu testler ---

  test "geçersiz anahtar 401" do
    assert_no_difference -> { Alert.count } do
      post_event event_action: "trigger", dedup_key: "x", summary: "y", key: "yanlis-anahtar"
    end
    assert_response :unauthorized
  end

  test "trigger yeni olay açar" do
    assert_difference -> { Alert.count }, 1 do
      post_event event_action: "trigger", dedup_key: "cpu-high-web1", summary: "web1 CPU %99", severity: "critical"
    end

    assert_response :accepted
    alert = Alert.find(response.parsed_body["alert_id"])
    assert_equal({ "status" => "triggered", "alert_id" => alert.id, "dedup_key" => "cpu-high-web1" }, response.parsed_body)
    assert alert.triggered?
    assert alert.high?
    assert_equal "web1 CPU %99", alert.title
    assert_equal @service, alert.service
    assert_equal Time.current, alert.triggered_at
  end

  test "aynı dedup_key ile ikinci trigger olay açmaz" do
    open_alert = alerts(:triggered)

    assert_no_difference -> { Alert.count } do
      post_event event_action: "trigger", dedup_key: open_alert.dedup_key, summary: "db1 disk %97"
    end

    assert_response :accepted
    assert_equal "deduplicated", response.parsed_body["status"]
    assert_equal open_alert.id, response.parsed_body["alert_id"]
    assert_equal "deduplicated", open_alert.alert_events.last.kind
  end

  test "resolve olayı kapatır" do
    alert = alerts(:triggered)

    post_event event_action: "resolve", dedup_key: alert.dedup_key

    assert_response :accepted
    assert_equal "resolved", response.parsed_body["status"]
    assert alert.reload.resolved?
    assert_nil alert.alert_events.last.user
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
      assert_no_difference -> { Alert.count } do
        post api_v1_events_path, params: body, headers: auth_headers.merge("Content-Type" => "application/json")
      end
      assert_response :unprocessable_entity, "Gövde: #{body}"
      assert response.parsed_body["error"].present?
    end
  end

  # --- Ek durumlar ---

  test "çözülmüş olayın dedup_key'i ile trigger yeni olay açar" do
    assert_difference -> { Alert.count }, 1 do
      post_event event_action: "trigger", dedup_key: alerts(:resolved).dedup_key, summary: "Sertifika yine"
    end
    assert_equal "triggered", response.parsed_body["status"]
  end

  test "acknowledge açık olayı üstlenir" do
    alert = alerts(:triggered)

    post_event event_action: "acknowledge", dedup_key: alert.dedup_key

    assert_response :accepted
    assert_equal "acknowledged", response.parsed_body["status"]
    assert alert.reload.acknowledged?
  end

  test "açık olayı olmayan dedup_key için acknowledge/resolve 404" do
    %w[acknowledge resolve].each do |action|
      post_event event_action: action, dedup_key: "olmayan-anahtar"
      assert_response :not_found
    end
  end

  test "izin verilmeyen geçiş 409" do
    post_event event_action: "acknowledge", dedup_key: alerts(:acknowledged).dedup_key
    assert_response :conflict
  end

  test "trigger seviye 0 nöbetçisine bildirim gönderir, assignee atar ve escalate_at ayarlar" do
    assert_difference -> { users(:alice).notifications.count }, 1 do
      post_event event_action: "trigger", dedup_key: "disk-full-db2", summary: "db2 disk %95", severity: "error"
    end

    alert = Alert.find(response.parsed_body["alert_id"])
    assert_equal users(:alice), alert.assignee
    assert_equal 5.minutes.from_now, alert.escalate_at
    assert_equal %w[triggered notified], alert.alert_events.map(&:kind)
    assert_equal users(:alice).id, alert.alert_events.last.details["user_id"]
  end

  test "severity warning, info veya yoksa low; low olayda escalate_at nil ama bildirim gider" do
    [ "warning", "info", nil ].each_with_index do |severity, i|
      post_event(**{ event_action: "trigger", dedup_key: "low-#{i}", summary: "Uyarı", severity: severity }.compact)

      alert = Alert.find(response.parsed_body["alert_id"])
      assert alert.low?, "severity: #{severity.inspect}"
      assert_nil alert.escalate_at
      assert_equal users(:alice), alert.assignee
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
