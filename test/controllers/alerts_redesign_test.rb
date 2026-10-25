require "test_helper"

class AlertsRedesignTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:bob)
  end

  test "liste: sayfa başlığı, durum ve aciliyet filtre pill'leri, rozetler, tablo bileşeni; canlı akış" do
    get alerts_path
    assert_select ".page-header .eyebrow"
    assert_select ".page-header h1", "Alarmlar"
    assert_select ".filters[aria-label='Durum filtresi'] a.filter-pill", 5
    assert_select ".filters[aria-label='Aciliyet filtresi'] a.filter-pill", 3
    assert_select ".filters a.filter-pill[aria-current=true]", text: "Açık"
    assert_select ".table-wrap table.table td .badge--critical", text: "Tetiklendi"
    assert_select ".table-wrap table.table td .badge--critical", text: "Yüksek"
    assert_select "td.mono", text: "#ALR-%03d" % alerts(:triggered).id
    assert_select "turbo-cable-stream-source"
    assert_select "nav > ul", count: 0, message: "madde işaretli eski filtre listesi kalmamalı"
  end

  test "varsayılan açık alarmlar; 'Tümü' çözülmüşleri de gösterir" do
    get alerts_path
    assert_select "td", text: alerts(:resolved).title, count: 0
    get alerts_path(status: "all")
    assert_select "td", text: alerts(:resolved).title
  end

  test "aciliyet filtresi ve arama" do
    get alerts_path(urgency: "low", status: "all")
    assert_select "td", text: alerts(:resolved).title
    assert_select "td", text: alerts(:triggered).title, count: 0

    get alerts_path(q: "disk", status: "all")
    assert_select "td", text: alerts(:triggered).title
    assert_select "td", text: alerts(:acknowledged).title, count: 0
  end

  test "boş liste: empty state" do
    Alert.update_all(status: Alert.statuses[:resolved])
    get alerts_path
    assert_select ".empty-state .empty-state__message"
  end

  test "detay: 2/3 + 1/3, rozetler, zaman çizelgesi bileşeni, eylem kartı" do
    alert = Alert.trigger!(service: services(:sis), title: "web1 CPU %99", dedup_key: "cpu-web1", urgency: :high)
    get alert_path(alert)
    assert_select ".detail-grid"
    assert_select "h1", alert.title
    assert_select ".badge--critical", text: "Tetiklendi"
    assert_select "ol.timeline li.timeline__item", minimum: 1
    assert_select "aside .card button", text: "Gördüm"
    assert_select "aside .card a.btn", text: "Olay ilan et"
  end

  test "Gördüm canlı yenileme yayınlar" do
    alert = alerts(:triggered)
    assert_turbo_stream_broadcasts :alerts do
      post acknowledge_alert_path(alert)
    end
    assert alert.reload.acknowledged?
  end
end
