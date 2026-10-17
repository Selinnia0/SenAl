require "test_helper"

# Z5: Boşluk tespiti ve önceden uyarı (adaptasyon).
# Fixture'lar: BT Altyapı (primary) = Ayşe, Burak; Laboratuvar (secondary) = Burak, Yönetici.
class GapReportTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @schedule = schedules(:primary)
    @manager = users(:manager)
  end

  test "tüm üyeler aynı gün izinliyse o gün gaps içinde tek bir aralık olarak çıkar" do
    day_start = Time.zone.parse("2026-10-21 00:00")
    day_end = Time.zone.parse("2026-10-22 00:00")
    @schedule.members.each { |user| user.unavailabilities.create!(starts_at: day_start, ends_at: day_end) }

    assert_equal [ day_start...day_end ], @schedule.gaps(from: Time.current, to: 7.days.from_now)
  end

  test "boşluk yoksa yöneticiye bildirim gitmez" do
    assert_no_difference -> { Notification.count } do
      GapReport.run!(horizon: 7.days)
    end
  end

  test "8 gün sonraki bir boşluk 7 günlük ufukta raporlanmaz; 1 gün sonra raporlanır" do
    day_start = Time.zone.parse("2026-10-27 00:00") # çapadan 8 gün sonrası
    @schedule.members.each do |user|
      user.unavailabilities.create!(starts_at: day_start, ends_at: day_start + 1.day)
    end

    assert_no_difference -> { @manager.notifications.count } do
      GapReport.run!(horizon: 7.days)
    end

    travel 1.day
    assert_difference -> { @manager.notifications.count }, 1 do
      GapReport.run!(horizon: 7.days)
    end
    assert_includes @manager.notifications.last.message, @schedule.name
  end

  # --- Ek durumlar ---

  test "ardışık boş saatler birleşir, ayrı boşluklar ayrı aralık olur" do
    first = Time.zone.parse("2026-10-20 08:00")...Time.zone.parse("2026-10-20 11:00")
    second = Time.zone.parse("2026-10-20 14:00")...Time.zone.parse("2026-10-20 15:00")
    @schedule.members.each do |user|
      [ first, second ].each { |range| user.unavailabilities.create!(starts_at: range.begin, ends_at: range.end) }
    end

    assert_equal [ first, second ], @schedule.gaps(from: Time.current, to: 2.days.from_now)
  end

  test "aralık sonuna kadar süren boşluk to'da kesilir" do
    @schedule.members.each { |user| user.unavailabilities.create!(starts_at: 1.hour.from_now, ends_at: 10.days.from_now) }

    assert_equal [ 1.hour.from_now...1.day.from_now ], @schedule.gaps(from: Time.current, to: 1.day.from_now)
  end

  test "her yöneticiye tek bildirim; tüm boşluklu takvimler aynı mesajda" do
    other_manager = User.create!(name: "İkinci Yönetici", email_address: "y2@example.com", password: "sifre-123", role: :manager)
    BlackoutPeriod.create!(name: "Bayram", kind: :holiday, applies_to: :everyone,
                           starts_on: Date.new(2026, 10, 21), ends_on: Date.new(2026, 10, 21))

    assert_difference -> { Notification.count }, 2 do
      GapReport.run!(horizon: 7.days)
    end

    [ @manager, other_manager ].each do |manager|
      message = manager.notifications.sole.message
      assert_includes message, schedules(:primary).name
      assert_includes message, schedules(:secondary).name
      assert_includes message, "21.10.2026 00:00"
    end
    assert_empty users(:alice).notifications
  end
end
