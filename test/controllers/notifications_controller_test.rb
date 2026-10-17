require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:alice)
    @mine = users(:alice).notifications.create!(incident: incidents(:triggered))
    @gap = users(:alice).notifications.create!(message: "Nöbet boşluğu: Laboratuvar")
    @others = users(:bob).notifications.create!(incident: incidents(:acknowledged))
  end

  test "okunmamış bildirimlerimi gösterir" do
    get notifications_path
    assert_response :success
    assert_select "td", text: incidents(:triggered).title
    assert_select "td", text: /Laboratuvar/
    assert_select "td", text: incidents(:acknowledged).title, count: 0
  end

  test "bildirim okundu işaretlenir ve listeden düşer" do
    patch read_notification_path(@mine)
    assert_predicate @mine.reload.read_at, :present?

    get notifications_path
    assert_select "td", text: incidents(:triggered).title, count: 0
  end

  test "tümü okundu" do
    patch read_all_notifications_path
    assert_empty users(:alice).notifications.unread
    assert_predicate @others.reload.read_at, :nil?
  end

  test "başkasının bildirimi işaretlenemez" do
    patch read_notification_path(@others)
    assert_response :not_found
  end

  test "menüde okunmamış bildirim sayısı görünür" do
    get notifications_path
    assert_select "nav a", text: "Bildirimlerim (2)"
  end
end
