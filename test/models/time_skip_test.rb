require "test_helper"

# Demo aracı: "N dakika ileri sar" = açık olayların zamanlarını N dakika geriye kaydırıp her
# eskalasyon/bayatlama anında gerçek süpürme metotlarını çalıştırmak. Gerçek saat değişmez.
# Fixture politikası: seviye 0 Ayşe, seviye 1 Burak, 5'er dk, repeat_count 1.
class TimeSkipTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob = users(:alice), users(:bob)
    @alert = Alert.trigger!(service: services(:sis), title: "Sıçrama", dedup_key: "skip", urgency: :high)
  end

  test "4 dakika sıçrama eskale etmez ama zamanlayıcıyı ilerletir" do
    TimeSkip.new(minutes: 4).run!
    @alert.reload

    assert_equal 0, @alert.current_level
    assert_equal 4.minutes.ago, @alert.triggered_at
    assert_equal 1.minute.from_now, @alert.escalate_at
  end

  test "12 dakika sıçrama 5. ve 10. dakikalarda iki kez eskale eder; zaman çizelgesi tutarlı" do
    TimeSkip.new(minutes: 12).run!
    @alert.reload

    assert_equal [ 0, 1 ], [ @alert.current_level, @alert.escalation_round ]
    assert_equal @alice, @alert.assignee
    assert_equal [ @alice, @bob, @alice ], @alert.notifications.order(:id).map(&:user)
    assert_equal 12.minutes.ago, @alert.triggered_at
    assert_equal [ 7.minutes.ago, 2.minutes.ago ], @alert.alert_events.where(kind: "escalated").map(&:occurred_at)
    assert_equal 3.minutes.from_now, @alert.escalate_at
  end

  test "gerçek saat değişmez" do
    before = Time.current
    TimeSkip.new(minutes: 60).run!
    assert_equal before, Time.current
  end

  test "4 saat sıçrama bayatlamış gördüm'ü yeniden tetikler ve seviye 0'a bildirir" do
    @alert.acknowledge!(by: @bob)

    TimeSkip.new(minutes: 240).run!
    @alert.reload

    assert @alert.triggered?
    assert_equal 0, @alert.current_level
    assert_equal @alice, @alert.assignee
    assert_equal %w[retriggered notified], @alert.alert_events.last(2).map(&:kind)
    assert_equal 5.minutes.from_now, @alert.escalate_at
  end

  test "çözülmüş olaylara dokunmaz" do
    resolved = alerts(:resolved)

    assert_no_changes -> { resolved.reload.attributes } do
      TimeSkip.new(minutes: 30).run!
    end
  end

  test "sonuç özeti oluşan zaman çizelgesi kayıtlarını türüne göre sayar" do
    summary = TimeSkip.new(minutes: 5).run!
    assert_operator summary["escalated"], :>=, 1
  end

  test "süre 1 dakika ile 7 gün (10080 dk) arasında olmalı" do
    [ 0, -5, 10_081, nil ].each do |minutes|
      skip_request = TimeSkip.new(minutes: minutes)
      assert_not skip_request.valid?, "minutes: #{minutes.inspect}"
      assert_raises(ActiveModel::ValidationError) { skip_request.run! }
    end
    assert TimeSkip.new(minutes: 10_080).valid?
  end

  # --- v2 response katmanı: olaylar da ileri sarılır ---

  test "olay zamanları da kayar: +30 dk critical olayda güncelleme hatırlatıcısı düşer, zaman çizelgesi tutarlı" do
    incident = Incident.declare!(service: services(:sis), title: "Sıçrama olayı", severity: :critical,
                                 lead: @alice, by: @bob)

    TimeSkip.new(minutes: 30).run!
    incident.reload

    assert_equal 30.minutes.ago, incident.declared_at
    assert_equal 30.minutes.ago, incident.timeline_events.first.occurred_at
    assert_includes Incident.update_overdue, incident
    assert_equal [ @alice ], incident.notifications.map(&:user)
  end

  test "+5 gün: çözülmüş critical olayda postmortem hatırlatıcısı düşer" do
    incident = Incident.declare!(service: services(:sis), title: "Postmortem olayı", severity: :critical,
                                 lead: @alice, by: @bob)
    incident.transition_to!(:investigating, by: @alice)
    incident.transition_to!(:resolved, by: @alice)

    TimeSkip.new(minutes: 5 * 24 * 60).run!
    incident.reload

    assert_equal 5.days.ago, incident.resolved_at
    assert_includes Incident.postmortem_overdue, incident
    assert(incident.notifications.any? { |notification| notification.message.match?(/postmortem/i) })
  end

  test "+7 gün 1 dk: halka açık çözülmüş olay durum sayfası geçmişinden düşer" do
    incident = Incident.declare!(service: services(:sis), title: "Halka açık", severity: :minor,
                                 public_impact: true, lead: @alice, by: @bob)
    incident.transition_to!(:investigating, by: @alice)
    incident.publish_status_update!(public_status: :investigating, message: "İnceliyoruz.", by: @alice)
    incident.transition_to!(:resolved, by: @alice)
    assert_includes Incident.recent_for_status_page, incident

    TimeSkip.new(minutes: TimeSkip::MAX_MINUTES).run! # 7 gün: sınır dahil, hâlâ görünür
    assert_includes Incident.recent_for_status_page, incident

    TimeSkip.new(minutes: 1).run!
    assert_not_includes Incident.recent_for_status_page, incident
    assert_equal (7.days + 1.minute).ago, incident.status_page_updates.reload.last.published_at
  end
end
