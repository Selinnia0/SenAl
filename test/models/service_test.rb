require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "oluşturulurken 32 karakterlik integration_key üretilir" do
    service = Service.create!(name: "Kütüphane", escalation_policy: escalation_policies(:default))
    assert_match(/\A\h{32}\z/, service.integration_key)
  end

  test "verilen integration_key ezilmez" do
    service = Service.create!(name: "Kütüphane", escalation_policy: escalation_policies(:default), integration_key: "sabit")
    assert_equal "sabit", service.integration_key
  end
end
