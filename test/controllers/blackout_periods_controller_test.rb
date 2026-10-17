require "test_helper"

class BlackoutPeriodsControllerTest < ActionDispatch::IntegrationTest
  test "manager olmayan kullanıcı akademik takvime erişemez" do
    sign_in_as users(:bob)

    get blackout_periods_path
    assert_redirected_to root_path

    assert_no_difference -> { BlackoutPeriod.count } do
      post blackout_periods_path, params: { blackout_period: valid_params }
    end
    assert_redirected_to root_path
  end

  test "manager akademik dönem ekler, düzenler ve siler" do
    sign_in_as users(:manager)

    assert_difference -> { BlackoutPeriod.count }, 1 do
      post blackout_periods_path, params: { blackout_period: valid_params }
    end
    assert_redirected_to blackout_periods_path
    period = BlackoutPeriod.last
    assert period.exam_week?
    assert period.assistants?

    patch blackout_period_path(period), params: { blackout_period: { name: "Final Haftası" } }
    assert_equal "Final Haftası", period.reload.name

    assert_difference -> { BlackoutPeriod.count }, -1 do
      delete blackout_period_path(period)
    end
  end

  test "bitişi başlangıçtan önce olan dönem 422" do
    sign_in_as users(:manager)
    post blackout_periods_path, params: { blackout_period: valid_params.merge(ends_on: "2026-10-01") }
    assert_response :unprocessable_entity
  end

  private
    def valid_params
      { name: "2026 Güz Vize Haftası", kind: "exam_week", applies_to: "assistants",
        starts_on: "2026-10-26", ends_on: "2026-10-30" }
    end
end
