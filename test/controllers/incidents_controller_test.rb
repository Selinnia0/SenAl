require "test_helper"

class IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:alice)
  end

  test "giriş yapmamış kullanıcı olayları göremez" do
    sign_out
    get incidents_path
    assert_redirected_to new_session_path
  end

  test "liste duruma göre filtrelenir" do
    get incidents_path(status: "acknowledged")
    assert_response :success
    assert_select "td", text: incidents(:acknowledged).title
    assert_select "td", text: incidents(:triggered).title, count: 0
  end

  test "liste filtresiz tüm olayları gösterir; geçersiz filtre yok sayılır" do
    get incidents_path(status: "uydurma")
    assert_response :success
    Incident.find_each { |incident| assert_select "td", text: incident.title }
  end

  test "triggered olayda Gördüm ve Çözüldü butonları görünür" do
    get incident_path(incidents(:triggered))
    assert_select "button", text: "Gördüm"
    assert_select "button", text: "Çözüldü"
  end

  test "acknowledged olayda yalnızca Çözüldü butonu görünür" do
    get incident_path(incidents(:acknowledged))
    assert_select "button", text: "Gördüm", count: 0
    assert_select "button", text: "Çözüldü"
  end

  test "resolved olayda buton görünmez" do
    get incident_path(incidents(:resolved))
    assert_select "button", text: "Gördüm", count: 0
    assert_select "button", text: "Çözüldü", count: 0
  end

  test "Gördüm olayı giriş yapan kullanıcı adına üstlenir" do
    incident = incidents(:triggered)
    post acknowledge_incident_path(incident)

    assert_redirected_to incident_path(incident)
    assert incident.reload.acknowledged?
    assert_equal users(:alice), incident.incident_events.last.user
  end

  test "Çözüldü olayı kapatır" do
    incident = incidents(:acknowledged)
    post resolve_incident_path(incident)

    assert_redirected_to incident_path(incident)
    assert incident.reload.resolved?
  end

  test "izin verilmeyen geçiş hata mesajıyla reddedilir" do
    incident = incidents(:resolved)
    post acknowledge_incident_path(incident)

    assert_redirected_to incident_path(incident)
    assert incident.reload.resolved?
    follow_redirect!
    assert_select "[role=alert]", /izin verilmiyor/
  end

  test "detay sayfası zaman çizelgesini gösterir" do
    incident = incidents(:triggered)
    incident.acknowledge!(by: users(:bob))

    get incident_path(incident)
    assert_select "ol li", /Burak Demir/
  end
end
