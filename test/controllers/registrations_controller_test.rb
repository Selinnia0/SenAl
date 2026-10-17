require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "kayıt sayfası açılır" do
    get new_registration_path
    assert_response :success
    assert_select "h1", "Kayıt ol"
  end

  test "geçerli bilgilerle kayıt olunur ve oturum açılır" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: { user: {
        name: "Can Öz", email_address: "can@example.com", academic_role: "assistant",
        password: "gizli-sifre", password_confirmation: "gizli-sifre"
      } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?
    user = User.find_by!(email_address: "can@example.com")
    assert user.responder?
    assert user.assistant?
  end

  test "kayıt olan kullanıcı kendini manager yapamaz" do
    post registration_path, params: { user: {
      name: "Sinsi", email_address: "sinsi@example.com", role: "manager",
      password: "gizli-sifre", password_confirmation: "gizli-sifre"
    } }

    assert User.find_by!(email_address: "sinsi@example.com").responder?
  end

  test "hatalı bilgilerle kayıt olunmaz" do
    assert_no_difference -> { User.count } do
      post registration_path, params: { user: {
        name: "", email_address: users(:alice).email_address,
        password: "a", password_confirmation: "b"
      } }
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
  end

  test "giriş sayfasında kayıt bağlantısı var" do
    get new_session_path
    assert_select "a[href=?]", new_registration_path
  end
end
