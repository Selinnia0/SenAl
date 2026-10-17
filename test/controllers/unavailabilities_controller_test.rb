require "test_helper"

class UnavailabilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:alice)
  end

  test "kullanıcı kendi iznini ekler" do
    assert_difference -> { users(:alice).unavailabilities.count }, 1 do
      post unavailabilities_path, params: { unavailability: {
        starts_at: "2026-10-22T00:00", ends_at: "2026-10-24T00:00", reason: "Konferans"
      } }
    end
    assert_redirected_to unavailabilities_path
    assert_not users(:alice).available_at?(Time.zone.parse("2026-10-23 12:00"))
  end

  test "başka kullanıcı adına izin eklenemez" do
    post unavailabilities_path, params: { unavailability: {
      user_id: users(:bob).id, starts_at: "2026-10-22T00:00", ends_at: "2026-10-24T00:00"
    } }
    assert_empty users(:bob).unavailabilities
  end

  test "liste yalnızca kendi izinlerini gösterir" do
    users(:alice).unavailabilities.create!(starts_at: 1.day.from_now, ends_at: 2.days.from_now, reason: "Benim iznim")
    users(:bob).unavailabilities.create!(starts_at: 1.day.from_now, ends_at: 2.days.from_now, reason: "Burak'ın izni")

    get unavailabilities_path
    assert_select "td", text: "Benim iznim"
    assert_select "td", text: "Burak'ın izni", count: 0
  end

  test "kendi iznini siler, başkasınınkini silemez" do
    mine = users(:alice).unavailabilities.create!(starts_at: 1.day.from_now, ends_at: 2.days.from_now)
    others = users(:bob).unavailabilities.create!(starts_at: 1.day.from_now, ends_at: 2.days.from_now)

    delete unavailability_path(mine)
    assert_not Unavailability.exists?(mine.id)

    delete unavailability_path(others)
    assert_response :not_found
    assert Unavailability.exists?(others.id)
  end

  test "geçersiz izin 422" do
    post unavailabilities_path, params: { unavailability: { starts_at: "2026-10-24T00:00", ends_at: "2026-10-22T00:00" } }
    assert_response :unprocessable_entity
  end
end
