require "test_helper"

class TimeSkipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
  end

  test "manager formu görür ve ileri sarar" do
    sign_in_as users(:manager)
    incident = incidents(:triggered) # escalate_at 10:05

    get new_time_skip_path
    assert_response :success
    assert_select "input[name='time_skip[minutes]']"

    post time_skip_path, params: { time_skip: { minutes: 5 } }
    assert_redirected_to new_time_skip_path
    assert_equal 1, incident.reload.current_level
    follow_redirect!
    assert_select "[role=alert]", /5 dakika ileri sarıldı/
  end

  test "geçersiz süre 422" do
    sign_in_as users(:manager)
    post time_skip_path, params: { time_skip: { minutes: 0 } }
    assert_response :unprocessable_entity
  end

  test "manager olmayan kullanıcı ileri saramaz" do
    sign_in_as users(:alice)
    incident = incidents(:triggered)

    post time_skip_path, params: { time_skip: { minutes: 5 } }
    assert_redirected_to root_path
    assert_equal 0, incident.reload.current_level
  end

  test "özellik kapalıysa 404 ve menüde görünmez" do
    sign_in_as users(:manager)
    with_time_skip(false) do
      get new_time_skip_path
      assert_response :not_found

      post time_skip_path, params: { time_skip: { minutes: 5 } }
      assert_response :not_found
      assert_equal 0, incidents(:triggered).reload.current_level

      get root_path
      assert_select "nav a", text: "Zaman sıçraması", count: 0
    end
  end

  test "özellik açıkken manager menüsünde görünür" do
    sign_in_as users(:manager)
    get root_path
    assert_select "nav a", text: "Zaman sıçraması"
  end

  private
    def with_time_skip(enabled)
      previous = Rails.configuration.x.time_skip_enabled
      Rails.configuration.x.time_skip_enabled = enabled
      yield
    ensure
      Rails.configuration.x.time_skip_enabled = previous
    end
end
