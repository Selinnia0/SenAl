require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  test "manager olmayan kullanıcı servis sayfalarına erişemez" do
    sign_in_as users(:alice)
    service = services(:sis)

    get services_path
    assert_redirected_to root_path
    get service_path(service)
    assert_redirected_to root_path
    get new_service_path
    assert_redirected_to root_path

    assert_no_difference -> { Service.count } do
      post services_path, params: { service: { name: "Sinsi", escalation_policy_id: escalation_policies(:default).id } }
    end
    assert_redirected_to root_path

    delete service_path(service)
    assert Service.exists?(service.id)
  end

  test "manager servis oluşturur, entegrasyon anahtarı üretilir" do
    sign_in_as users(:manager)

    assert_difference -> { Service.count }, 1 do
      post services_path, params: { service: { name: "Kütüphane", escalation_policy_id: escalation_policies(:default).id } }
    end
    service = Service.find_by!(name: "Kütüphane")
    assert_redirected_to service_path(service)
    assert_predicate service.integration_key, :present?
  end

  test "servis detayı integration_key ve kopyalanabilir curl örneği gösterir" do
    sign_in_as users(:manager)
    service = services(:sis)

    get service_path(service)
    assert_response :success
    assert_select "code", text: service.integration_key
    assert_select "pre", /curl -X POST .*\/api\/v1\/events/m
    assert_select "pre", /Token token=#{service.integration_key}/
    assert_select "button", text: "Kopyala"
  end

  test "geçersiz servis formu 422 döner" do
    sign_in_as users(:manager)
    post services_path, params: { service: { name: "", escalation_policy_id: escalation_policies(:default).id } }
    assert_response :unprocessable_entity
  end
end
