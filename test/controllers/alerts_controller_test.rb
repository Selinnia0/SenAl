require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:alice)
  end

  test "giriş yapmamış kullanıcı olayları göremez" do
    sign_out
    get alerts_path
    assert_redirected_to new_session_path
  end

  test "liste duruma göre filtrelenir" do
    get alerts_path(status: "acknowledged")
    assert_response :success
    assert_select "td", text: alerts(:acknowledged).title
    assert_select "td", text: alerts(:triggered).title, count: 0
  end

  test "liste filtresiz tüm olayları gösterir; geçersiz filtre yok sayılır" do
    get alerts_path(status: "uydurma")
    assert_response :success
    Alert.find_each { |alert| assert_select "td", text: alert.title }
  end

  test "triggered olayda Gördüm ve Çözüldü butonları görünür" do
    get alert_path(alerts(:triggered))
    assert_select "button", text: "Gördüm"
    assert_select "button", text: "Çözüldü"
  end

  test "acknowledged olayda yalnızca Çözüldü butonu görünür" do
    get alert_path(alerts(:acknowledged))
    assert_select "button", text: "Gördüm", count: 0
    assert_select "button", text: "Çözüldü"
  end

  test "resolved olayda buton görünmez" do
    get alert_path(alerts(:resolved))
    assert_select "button", text: "Gördüm", count: 0
    assert_select "button", text: "Çözüldü", count: 0
  end

  test "Gördüm olayı giriş yapan kullanıcı adına üstlenir" do
    alert = alerts(:triggered)
    post acknowledge_alert_path(alert)

    assert_redirected_to alert_path(alert)
    assert alert.reload.acknowledged?
    assert_equal users(:alice), alert.alert_events.last.user
  end

  test "Çözüldü olayı kapatır" do
    alert = alerts(:acknowledged)
    post resolve_alert_path(alert)

    assert_redirected_to alert_path(alert)
    assert alert.reload.resolved?
  end

  test "izin verilmeyen geçiş hata mesajıyla reddedilir" do
    alert = alerts(:resolved)
    post acknowledge_alert_path(alert)

    assert_redirected_to alert_path(alert)
    assert alert.reload.resolved?
    follow_redirect!
    assert_select "[role=alert]", /izin verilmiyor/
  end

  test "detay sayfası zaman çizelgesini gösterir" do
    alert = alerts(:triggered)
    alert.acknowledge!(by: users(:bob))

    get alert_path(alert)
    assert_select "ol li", /Burak Demir/
  end
end
