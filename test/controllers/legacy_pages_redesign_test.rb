require "test_helper"

# Eski (Pico dönemi) ekranlar tasarım sistemine taşındı: sayfa başlığı bileşeni, tablolar .table-wrap içinde,
# formlar kartta ve .field ile, madde işaretli nav/çıplak tablo yok.
class LegacyPagesRedesignTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    sign_in_as users(:manager)
    users(:manager).notifications.create!(message: "Nöbet boşluğu: Laboratuvar")
  end

  PAGES = {
    "takvimler" => -> { schedules_path },
    "takvim detayı" => -> { schedule_path(schedules(:primary)) },
    "müsaitliğim" => -> { unavailabilities_path },
    "akademik takvim" => -> { blackout_periods_path },
    "akademik dönem formu" => -> { new_blackout_period_path },
    "servisler" => -> { services_path },
    "servis detayı" => -> { service_path(services(:sis)) },
    "servis formu" => -> { new_service_path },
    "bildirimler" => -> { notifications_path },
    "zaman sıçraması" => -> { new_time_skip_path },
    "pano" => -> { dashboard_path }
  }.freeze

  PAGES.each do |name, path|
    test "#{name}: tasarım sistemi düzeni" do
      get instance_exec(&path)
      assert_response :success
      assert_select ".page-header h1", 1
      assert_select "nav > ul", count: 0
      css_select("main table").each do |table|
        assert table.ancestors.any? { |node| node["class"].to_s.split.include?("table-wrap") } || table["class"].to_s.include?("table"),
               "#{name}: tablo bileşen sınıfı olmadan"
      end
      css_select("main form:not(.button_to)").each do |form|
        next if form["role"] == "search"
        assert form.ancestors.any? { |node| node["class"].to_s.split.include?("card") },
               "#{name}: form kart içinde değil (#{form['action']})"
      end
    end
  end
end
