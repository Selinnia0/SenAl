require "test_helper"

class LandingTest < ActionDispatch::IntegrationTest
  test "landing (/) halka açık: hero, 4 modül kartı, kapanış bölümü" do
    get root_path
    assert_response :success

    assert_select ".hero h1"
    assert_select ".hero a.btn", minimum: 2
    assert_select ".modules .card", 4
    %w[Nöbet Olay\ yönetimi Durum\ sayfası Post-incident].each { |name| assert_select ".modules .card h3", text: name }
    assert_select ".closing"
    assert_select "aside.sidebar", count: 0
  end

  test "giriş yapmamışa giriş, yapmışa panoya git bağlantısı" do
    get root_path
    assert_select ".hero a[href=?]", new_session_path

    sign_in_as users(:alice)
    get root_path
    assert_select ".hero a[href=?]", dashboard_path
  end

  test "landing'den halka açık durum sayfasına bağlantı var" do
    get root_path
    assert_select "a[href=?]", status_page_path
  end

  test "giriş sonrası panoya yönlendirir" do
    post session_path, params: { email_address: users(:alice).email_address, password: "password" }
    assert_redirected_to dashboard_path
  end

  test "pano giriş ister" do
    get dashboard_path
    assert_redirected_to new_session_path
  end
end
