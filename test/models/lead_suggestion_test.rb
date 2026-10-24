require "test_helper"

# Z6 (100+ adaptasyonu) yeni akışa bağlanır: olay ilan edilirken önerilen lead, servisin seviye 0
# takviminin şu anki nöbetçisidir; izinli veya akademik kapanma dönemindeki kişi önerilmez.
# Fixture'lar: BT Altyapı (seviye 0) = Ayşe (asistan), Burak (personel); 7 günlük rotasyon,
# 2026-10-19 10:00'da sıra Ayşe'de.
class LeadSuggestionTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
    @service = services(:sis)
  end

  test "öneri: seviye 0 takviminin şu anki nöbetçisi" do
    assert_equal @alice, Incident.suggested_lead(@service)
  end

  test "nöbetçi izindeyken önerilmez; rotasyondaki sıradaki müsait kişi önerilir; izin bitince geri döner" do
    leave_ends = 2.hours.from_now
    @alice.unavailabilities.create!(starts_at: 1.hour.ago, ends_at: leave_ends, reason: "Doktor")

    assert_equal @bob, Incident.suggested_lead(@service)
    assert_equal @alice, Incident.suggested_lead(@service, at: leave_ends)
  end

  test "vize haftasında asistan önerilmez, personel önerilir" do
    BlackoutPeriod.create!(name: "Vize haftası", kind: :exam_week, applies_to: :assistants,
                           starts_on: Date.current, ends_on: Date.current + 4)

    assert_equal @bob, Incident.suggested_lead(@service)
  end

  test "bayramda kimse önerilmez" do
    BlackoutPeriod.create!(name: "Bayram", kind: :holiday, applies_to: :everyone,
                           starts_on: Date.current, ends_on: Date.current)

    assert_nil Incident.suggested_lead(@service)
  end

  test "override ile nöbet verilen kişi izindeyse öneri yapılmaz (alarm çağrısı override'a uyar, öneri uymaz)" do
    @manager.unavailabilities.create!(starts_at: 1.hour.ago, ends_at: 1.day.from_now)
    schedules(:primary).overrides.create!(user: @manager, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)

    assert_equal @manager, OnCall.for(schedules(:primary), at: Time.current), "alarm çağrısı override'a uyar"
    assert_nil Incident.suggested_lead(@service)
  end

  test "eskalasyon seviyesi olmayan serviste öneri yok" do
    service = Service.create!(name: "Seviyesiz", escalation_policy: EscalationPolicy.create!(name: "Boş"))
    assert_nil Incident.suggested_lead(service)
  end

  test "öneri yan etkisizdir ve ilan sırasında lead yine elle verilir" do
    assert_no_changes -> { [ Incident.count, IncidentRoleAssignment.count, Notification.count ] } do
      Incident.suggested_lead(@service)
    end
  end
end
