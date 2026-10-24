require "test_helper"

class DesignSystemTest < ActionDispatch::IntegrationTest
  test "/design (yalnızca geliştirme/test) bütün bileşenleri gösterir" do
    sign_in_as users(:manager)
    get design_path
    assert_response :success

    %w[primary accent secondary ghost].each { |variant| assert_select ".btn.btn--#{variant}" }
    %w[critical major minor ok info accent neutral].each { |tone| assert_select ".badge.badge--#{tone}" }
    assert_select ".card"
    assert_select ".eyebrow"
    assert_select ".table-wrap table.table"
    assert_select "ol.timeline li.timeline__item", minimum: 3
    assert_select ".empty-state .empty-state__message"
    assert_select ".status-indicator .status-indicator__bars", minimum: 1 do |bars|
      bars.each { |bar_group| assert_equal 7, bar_group.css(".status-indicator__bar").size }
    end
    assert_select ".banner"
    assert_select ".toast"
    assert_select ".logo"
    assert_select "[data-token]", minimum: 10
  end

  test "giriş yapmadan /design açılmaz" do
    get design_path
    assert_redirected_to new_session_path
  end

  test "uygulama kabuğu: sidebar, üst bar, vurgulu 'Olay ilan et', fontlar; Pico yok" do
    sign_in_as users(:manager)
    get root_path

    assert_select "aside.sidebar nav.sidebar__nav"
    assert_select "aside.sidebar .logo"
    assert_select "header.topbar .btn--accent", text: "Olay ilan et"
    assert_select "a.sidebar__link[aria-current=page]", text: "Pano"
    assert_select "link[href*='fonts.googleapis.com'][href*='Newsreader'][href*='Inter'][href*='Geist+Mono']"
    assert_select "link[href*='pico']", count: 0
    assert_select "link[rel=stylesheet][href*='tokens']"
  end

  test "giriş sayfası auth düzenini kullanır: sidebar yok" do
    get new_session_path
    assert_select "main.auth .card h1", "Giriş yap"
    assert_select "aside.sidebar", count: 0
  end

  test "arayüzde orijinal marka adı geçmez (ödev kuralı)" do
    forbidden = /incident\.io|alarmalade|pagerduty/i
    files = Dir[Rails.root.join("{app/views,app/assets,app/helpers,app/javascript,public}/**/*.{erb,css,js,rb,svg,html}")]
    assert_operator files.size, :>, 20
    offenders = files.select { |path| File.read(path).match?(forbidden) }
    assert_empty offenders, "Marka adı geçen dosyalar: #{offenders.join(', ')}"
  end
end
