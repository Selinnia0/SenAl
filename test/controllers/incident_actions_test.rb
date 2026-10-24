require "test_helper"

# Olay detayındaki eylemler: güncelleme, durum sayfası güncellemesi, rol, takip görevi, postmortem.
class IncidentActionsTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
    @incident = incidents(:investigating_major)
    sign_in_as @bob
  end

  test "güncelleme yazar; Turbo Stream yanıtı toast ekler; canlı yenileme yayınlar" do
    assert_turbo_stream_broadcasts @incident do
      post incident_updates_path(@incident), params: { body: "Bağlantı havuzunu büyüttük." }, as: :turbo_stream
    end
    assert_response :success
    assert_match %(target="toasts"), response.body
    assert_equal "Bağlantı havuzunu büyüttük.", @incident.timeline_events.last.body
  end

  test "güncelleme HTML isteğinde detaya döner; boş güncelleme reddedilir" do
    post incident_updates_path(@incident), params: { body: "Not" }
    assert_redirected_to incident_path(@incident)

    assert_no_difference -> { @incident.timeline_events.count } do
      post incident_updates_path(@incident), params: { body: "" }
    end
    follow_redirect!
    assert_select "[role=alert]", /boş/i
  end

  test "durum sayfası güncellemesi yayınlar" do
    @incident.update!(public_impact: true)
    post incident_status_page_updates_path(@incident), params: { public_status: "identified", message: "Sorunu bulduk." }

    assert_redirected_to incident_path(@incident)
    assert @incident.status_page_updates.last.public_identified?
  end

  test "rol atar" do
    post incident_role_assignments_path(@incident), params: { role: "communications", user_id: @bob.id }
    assert_equal @bob, @incident.reload.communications_lead
  end

  test "takip görevi ekler ve tamamlar" do
    post incident_follow_ups_path(@incident), params: { follow_up: { title: "Alarm eşiğini düşür", owner_id: @bob.id, due_on: "2026-10-25" } }
    follow_up = @incident.follow_ups.last
    assert_equal "Alarm eşiğini düşür", follow_up.title

    patch complete_incident_follow_up_path(@incident, follow_up)
    assert follow_up.reload.completed?
  end

  test "postmortem yazar ve yayınlar; sonra olay kapatılabilir" do
    incident = incidents(:resolved_major)
    sign_in_as @alice # lead

    get edit_incident_postmortem_path(incident)
    assert_response :success
    patch incident_postmortem_path(incident), params: { postmortem: { body: "Kök neden: bağlantı sızıntısı." } }
    assert_equal "Kök neden: bağlantı sızıntısı.", incident.reload.postmortem.body
    assert_not incident.postmortem.published?

    post publish_incident_postmortem_path(incident)
    assert incident.postmortem.reload.published?

    post transition_incident_path(incident), params: { to: "closed" }
    assert incident.reload.closed?
  end

  test "post-incident listesi: gecikmiş postmortem ve açık takip görevleri" do
    incidents(:resolved_major).follow_ups.create!(title: "Runbook yaz", owner: @bob)
    travel 5.days

    get post_incident_path
    assert_response :success
    assert_select "td", text: incidents(:resolved_major).title
    assert_select ".badge", text: /gecikti/i
    assert_select "td", text: "Runbook yaz"
  end
end
