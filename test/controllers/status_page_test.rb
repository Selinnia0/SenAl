require "test_helper"

# Halka açık durum sayfası: giriş gerektirmez, yalnızca public_impact olaylar ve yayınlanmış mesajlar görünür.
class StatusPageTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    Incident.where(public_impact: true).update_all(public_impact: false) # fixture'dan bağımsız başla
    @service = services(:sis)
    @alice = users(:alice)
  end

  test "aktif halka açık olay yokken 'Tüm sistemler çalışıyor', giriş gerekmez" do
    get status_page_path
    assert_response :success
    assert_select "h1", "Tüm sistemler çalışıyor"
    assert_select ".status-indicator", Service.count
    assert_select ".status-indicator__state--operational", Service.count
    assert_select "aside.sidebar", count: 0
  end

  test "aktif critical halka açık olay → büyük kesinti; minor/major → kısmi kesinti; son mesaj görünür" do
    incident = declare(:critical)
    incident.publish_status_update!(public_status: :investigating, message: "Girişte sorun yaşanıyor, inceliyoruz.", by: @alice)

    get status_page_path
    assert_select "h1", /aktif olay/i
    assert_select ".status-indicator__state--major"
    assert_select ".public-incident", text: /Girişte sorun yaşanıyor/

    incident.change_severity!(:minor, by: @alice)
    get status_page_path
    assert_select ".status-indicator__state--partial"
  end

  test "iç (public olmayan) olay ve iç zaman çizelgesi notları görünmez" do
    internal = Incident.declare!(service: @service, title: "GİZLİ iç olay", severity: :critical, lead: @alice, by: @alice)
    internal.post_update!(body: "GİZLİ teşhis notu", by: @alice)
    public = declare(:major)
    public.post_update!(body: "İÇ NOT, yayınlanmaz", by: @alice)

    get status_page_path
    assert_no_match(/GİZLİ/, response.body)
    assert_no_match(/İÇ NOT/, response.body)
    assert_select ".status-indicator__state--partial"
  end

  test "çözülmüş olay 7 gün geçmişte görünür, sonra düşer (Z5)" do
    incident = declare(:major)
    incident.publish_status_update!(public_status: :investigating, message: "Yavaşlık var.", by: @alice)
    incident.transition_to!(:investigating, by: @alice)
    incident.transition_to!(:resolved, by: @alice)

    travel 6.days
    get status_page_path
    assert_select ".history .public-incident", text: /Yavaşlık var|Sorun giderildi/

    travel 1.day + 1.second
    get status_page_path
    assert_select ".history .public-incident", count: 0
  end

  test "son 7 gün çubukları: olayın yaşandığı gün işaretli" do
    declare(:critical)

    get status_page_path
    assert_select ".status-indicator__bars" do |groups|
      groups.each { |group| assert_equal 7, group.css(".status-indicator__bar").size }
    end
    assert_select ".status-indicator__bar--major", minimum: 1
  end

  private
    def declare(severity)
      Incident.declare!(service: @service, title: "Halka açık #{severity}", severity: severity,
                        public_impact: true, lead: @alice, by: @alice)
    end
end
