require "test_helper"

# Z6 (v1: Z4): Müsaitlik farkındalıklı rotasyon (adaptasyon).
# Ayşe (alice) asistan, Burak (bob) ve Yönetici (manager) personel.
class AvailabilityTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
  end

  test "nöbetçi A izindeyken nöbet sıradaki B'ye geçer; izin bitince A'ya döner" do
    schedule = build_schedule(@alice, @bob, @manager)
    leave_ends = 2.days.from_now
    @alice.unavailabilities.create!(starts_at: Time.current, ends_at: leave_ends, reason: "Yıllık izin")

    assert_equal @bob, OnCall.for(schedule, at: Time.current)
    assert_equal @bob, OnCall.for(schedule, at: leave_ends - 1.second)
    assert_equal @alice, OnCall.for(schedule, at: leave_ends)
  end

  test "A beş farklı takvimde; tek bir Unavailability kaydı beşinde de A'yı atlatır" do
    schedules = 5.times.map { |i| build_schedule(@alice, @bob, name: "Takvim #{i}") }
    schedules.each { |schedule| assert_equal @alice, OnCall.for(schedule, at: Time.current) }

    @alice.unavailabilities.create!(starts_at: 1.hour.ago, ends_at: 1.day.from_now)

    schedules.each { |schedule| assert_equal @bob, OnCall.for(schedule, at: Time.current) }
  end

  test "vize haftası assistants için tanımlıyken asistan atlanır, staff atlanmaz" do
    BlackoutPeriod.create!(name: "2026 Güz Vize Haftası", kind: :exam_week, applies_to: :assistants,
                           starts_on: Date.current, ends_on: Date.current + 4)

    assert_not @alice.available_at?(Time.current)
    assert @bob.available_at?(Time.current)

    assert_equal @bob, OnCall.for(build_schedule(@alice, @bob, name: "Asistan önde"), at: Time.current)
    assert_equal @bob, OnCall.for(build_schedule(@bob, @alice, name: "Personel önde"), at: Time.current)
  end

  test "bayram everyone için tanımlıyken herkes atlanır → OnCall.for nil döner" do
    BlackoutPeriod.create!(name: "Cumhuriyet Bayramı", kind: :holiday, applies_to: :everyone,
                           starts_on: Date.current, ends_on: Date.current)

    [ @alice, @bob, @manager ].each { |user| assert_not user.available_at?(Time.current) }
    assert_nil OnCall.for(build_schedule(@alice, @bob, @manager), at: Time.current)
  end

  test "BlackoutPeriod uçları dahildir: ends_on günü 23:59'da atlanır, ertesi gün 00:00'da atlanmaz" do
    ends_on = Date.new(2026, 10, 21)
    BlackoutPeriod.create!(name: "Dönem arası", kind: :semester_break, applies_to: :everyone,
                           starts_on: Date.new(2026, 10, 20), ends_on: ends_on)

    assert @bob.available_at?(Time.zone.parse("2026-10-19 23:59"))
    assert_not @bob.available_at?(Time.zone.parse("2026-10-20 00:00"))
    assert_not @bob.available_at?(Time.zone.parse("2026-10-21 23:59"))
    assert @bob.available_at?(Time.zone.parse("2026-10-22 00:00"))
  end

  # --- Ek durumlar ---

  test "Unavailability sınırları: starts_at dahil, ends_at hariç" do
    starts_at, ends_at = 1.hour.from_now, 3.hours.from_now
    @bob.unavailabilities.create!(starts_at: starts_at, ends_at: ends_at)

    assert @bob.available_at?(starts_at - 1.second)
    assert_not @bob.available_at?(starts_at)
    assert_not @bob.available_at?(ends_at - 1.second)
    assert @bob.available_at?(ends_at)
  end

  test "override müsaitlik kontrolünü atlar" do
    schedule = build_schedule(@bob)
    @alice.unavailabilities.create!(starts_at: 1.hour.ago, ends_at: 1.day.from_now)
    schedule.overrides.create!(user: @alice, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

    assert_equal @alice, OnCall.for(schedule, at: Time.current)
  end

  private
    def build_schedule(*members, name: "Rotasyon")
      Schedule.create!(name: name, starts_at: Time.current, rotation_days: 7).tap do |schedule|
        members.each_with_index { |user, position| schedule.schedule_memberships.create!(user: user, position: position) }
      end
    end
end
