require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "giriş yapmamış kullanıcı giriş sayfasına yönlendirilir" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "giriş yapmış kullanıcı panoyu görür" do
    sign_in_as users(:alice)
    get root_path
    assert_response :success
    assert_select "h1", "SenAl"
  end

  test "giriş sayfası Türkçe" do
    get new_session_path
    assert_response :success
    assert_select "h1", "Giriş yap"
  end
end
