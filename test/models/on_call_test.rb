require "test_helper"

class OnCallTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")

    @first, @second, @third = users(:alice), users(:bob), users(:manager)
    @schedule = Schedule.create!(name: "Rotasyon", starts_at: Time.current, rotation_days: 7)
    [ @first, @second, @third ].each_with_index do |user, position|
      @schedule.schedule_memberships.create!(user: user, position: position)
    end
  end

  test "3 kişi, 7 günlük rotasyon: 0., 7., 14. gün sırayla 1., 2., 3. kişi; 21. gün tekrar 1. kişi" do
    assert_equal @first, OnCall.for(@schedule, at: Time.current)
    assert_equal @second, OnCall.for(@schedule, at: 7.days.from_now)
    assert_equal @third, OnCall.for(@schedule, at: 14.days.from_now)
    assert_equal @first, OnCall.for(@schedule, at: 21.days.from_now)
  end

  test "devir anından 1 saniye önce eski kişi, devir anında yeni kişi" do
    handoff = 7.days.from_now

    assert_equal @first, OnCall.for(@schedule, at: handoff - 1.second)
    assert_equal @second, OnCall.for(@schedule, at: handoff)
  end

  test "override aralığında override kişisi, aralık bitince rotasyon kişisi" do
    starts_at = 1.day.from_now
    ends_at = 2.days.from_now
    @schedule.overrides.create!(user: @third, starts_at: starts_at, ends_at: ends_at)

    assert_equal @first, OnCall.for(@schedule, at: starts_at - 1.second)
    assert_equal @third, OnCall.for(@schedule, at: starts_at)
    assert_equal @third, OnCall.for(@schedule, at: ends_at - 1.second)
    assert_equal @first, OnCall.for(@schedule, at: ends_at)
  end

  test "starts_at öncesi nil" do
    assert_nil OnCall.for(@schedule, at: 1.second.ago)
  end

  test "üyesi olmayan takvimde nil" do
    empty = Schedule.create!(name: "Boş", starts_at: Time.current, rotation_days: 7)
    assert_nil OnCall.for(empty, at: Time.current)
  end

  test "yan etkisizdir: hiçbir kayıt yazmaz" do
    assert_no_changes -> { [ Override.count, ScheduleMembership.count, IncidentEvent.count, Notification.count ] } do
      OnCall.for(@schedule, at: Time.current)
    end
  end

  test "fixture takvimleri çapada: BT Altyapı → Ayşe, Laboratuvar → Burak" do
    assert_equal users(:alice), OnCall.for(schedules(:primary), at: Time.current)
    assert_equal users(:bob), OnCall.for(schedules(:secondary), at: Time.current)
  end
end
