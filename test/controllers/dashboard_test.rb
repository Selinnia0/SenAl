require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:bob)
  end

  test "pano her takvimin şu anki nöbetçisini ve açık olayları gösterir" do
    get dashboard_path
    assert_response :success

    assert_select "td", text: "BT Altyapı"
    assert_select "td", text: "Ayşe Kaya"
    assert_select "td", text: alerts(:triggered).title
    assert_select "td", text: alerts(:acknowledged).title
    assert_select "td", text: alerts(:resolved).title, count: 0
  end

  test "nöbetçisi olmayan takvim boşluk olarak işaretlenir" do
    schedules(:primary).schedule_memberships.destroy_all
    get dashboard_path
    assert_select "tr.gap td", text: "BT Altyapı"
  end
end
