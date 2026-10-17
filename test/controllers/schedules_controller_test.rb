require "test_helper"

class SchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:alice)
    @schedule = schedules(:primary)
  end

  test "takvim listesi" do
    get schedules_path
    assert_response :success
    assert_select "td", text: "BT Altyapı"
  end

  test "takvim detayı üyeleri ve 14 günlük nöbet tablosunu gösterir" do
    get schedule_path(@schedule)
    assert_response :success
    assert_select "li", text: /Ayşe Kaya/
    assert_select "table#on-call-days tbody tr", count: 14
    assert_select "tr.gap", count: 0
  end

  test "boşluk olan günler kırmızı (gap) işaretlenir" do
    day = Time.zone.parse("2026-10-21 00:00")
    @schedule.members.each { |user| user.unavailabilities.create!(starts_at: day, ends_at: day + 1.day) }

    get schedule_path(@schedule)
    assert_select "tr.gap", count: 1
    assert_select "tr.gap td", text: /21\.10\.2026/
  end

  test "override eklenir" do
    assert_difference -> { @schedule.overrides.count }, 1 do
      post schedule_overrides_path(@schedule), params: { override: {
        user_id: users(:manager).id, starts_at: "2026-10-20T09:00", ends_at: "2026-10-20T18:00"
      } }
    end
    assert_redirected_to schedule_path(@schedule)

    override = @schedule.overrides.last
    assert_equal Time.zone.parse("2026-10-20 09:00"), override.starts_at
    assert_equal users(:manager), OnCall.for(@schedule, at: Time.zone.parse("2026-10-20 12:00"))
  end

  test "geçersiz override 422" do
    post schedule_overrides_path(@schedule), params: { override: {
      user_id: users(:manager).id, starts_at: "2026-10-20T18:00", ends_at: "2026-10-20T09:00"
    } }
    assert_response :unprocessable_entity
  end

  test "override'ı yalnızca manager silebilir" do
    override = @schedule.overrides.create!(user: users(:bob), starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)

    delete schedule_override_path(@schedule, override)
    assert Override.exists?(override.id)

    sign_in_as users(:manager)
    delete schedule_override_path(@schedule, override)
    assert_not Override.exists?(override.id)
  end
end
