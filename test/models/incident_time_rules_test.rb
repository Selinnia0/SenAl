require "test_helper"

# v2 zaman kuralları (response katmanı):
#   Z3 güncelleme gecikmesi: aktif critical olayda 30 dk, major'da 60 dk güncelleme yoksa (minor: kural yok)
#   Z4 postmortem gecikmesi: critical/major olay çözüldükten 5 gün sonra postmortem yayınlanmamışsa
#   Z5 durum sayfası geçmişi: halka açık, çözülmüş olay 7 gün geçmişte görünür, sonra düşer
# Sınırlar dahil (<=), Alert.escalation_due ile aynı: tam 30. dakikada gecikmiş sayılır.
class IncidentTimeRulesTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.parse("2026-10-19 10:00")
    @alice, @bob, @manager = users(:alice), users(:bob), users(:manager)
  end

  # --- Z3: güncelleme gecikmesi ---

  test "Z3 critical: 29:59'da gecikmiş değil, 30:00'da gecikmiş; güncelleme yazınca düşer" do
    incident = declare(:critical)

    travel 29.minutes + 59.seconds
    assert_not_includes Incident.update_overdue, incident

    travel 1.second
    assert_includes Incident.update_overdue, incident

    incident.post_update!(body: "Hâlâ inceliyoruz.", by: @alice)
    assert_not_includes Incident.update_overdue, incident
  end

  test "Z3 major: 59:59'da gecikmiş değil, 60:00'da gecikmiş" do
    incident = declare(:major)

    travel 59.minutes + 59.seconds
    assert_not_includes Incident.update_overdue, incident

    travel 1.second
    assert_includes Incident.update_overdue, incident
  end

  test "Z3 minor olayda güncelleme gecikmesi kuralı yok" do
    incident = declare(:minor)
    travel 1.day
    assert_not_includes Incident.update_overdue, incident
  end

  test "Z3 durum geçişi de güncelleme sayılır" do
    incident = declare(:critical)
    travel 25.minutes
    incident.transition_to!(:investigating, by: @alice)

    travel 25.minutes
    assert_not_includes Incident.update_overdue, incident
  end

  test "Z3 yalnızca aktif olaylar: çözülmüş, kapanmış, reddedilmiş olay gecikmiş sayılmaz" do
    resolved = declare(:critical).tap do |incident|
      incident.transition_to!(:investigating, by: @alice)
      incident.transition_to!(:resolved, by: @alice)
    end
    declined = declare(:critical).tap { |incident| incident.transition_to!(:declined, by: @alice) }

    travel 2.hours
    overdue = Incident.update_overdue
    assert_not_includes overdue, resolved
    assert_not_includes overdue, declined
    assert_not_includes overdue, incidents(:closed_major)
  end

  test "Z3 hatırlatıcı: gecikince lead ve iletişim sorumlusuna bir kez bildirim; güncellemeden sonra tekrar" do
    incident = declare(:critical, communications: @bob)
    travel 30.minutes

    assert_difference -> { incident.notifications.count }, 2 do
      Incident.remind_overdue_updates!
    end
    assert_equal [ @alice, @bob ].sort_by(&:id), incident.notifications.map(&:user).sort_by(&:id)
    assert_match(/güncelleme/i, incident.notifications.first.message)
    assert_equal Time.current, incident.reload.update_reminder_sent_at

    travel 5.minutes
    assert_no_difference -> { incident.notifications.count } do
      Incident.remind_overdue_updates!
    end

    incident.post_update!(body: "Düzeltme yayında.", by: @alice)
    assert_nil incident.reload.update_reminder_sent_at
    travel 30.minutes
    assert_difference -> { incident.notifications.count }, 2 do
      Incident.remind_overdue_updates!
    end
  end

  # --- Z4: postmortem gecikmesi ---

  test "Z4 critical: çözüldükten 5 gün - 1 sn sonra gecikmiş değil, tam 5 günde gecikmiş; yayınlanınca düşer" do
    incident = resolved(:critical)

    travel 5.days - 1.second
    assert_not_includes Incident.postmortem_overdue, incident

    travel 1.second
    assert_includes Incident.postmortem_overdue, incident

    incident.create_postmortem!(body: "Taslak")
    assert_includes Incident.postmortem_overdue, incident, "yayınlanmamış taslak gecikmeyi kaldırmaz"

    incident.postmortem.publish!
    assert_not_includes Incident.postmortem_overdue, incident
  end

  test "Z4 major da kapsamda; minor değil" do
    major = resolved(:major)
    minor = resolved(:minor)

    travel 6.days
    assert_includes Incident.postmortem_overdue, major
    assert_not_includes Incident.postmortem_overdue, minor
  end

  test "Z4 yeniden açılan olay postmortem gecikmesinden çıkar" do
    incident = resolved(:critical)
    travel 6.days
    incident.transition_to!(:investigating, by: @alice)

    assert_not_includes Incident.postmortem_overdue, incident
  end

  test "Z4 son tarih: çözülme anı + 5 gün" do
    incident = resolved(:critical)
    assert_equal 5.days.from_now, incident.postmortem_due_at
    assert_nil declare(:minor).postmortem_due_at
  end

  test "Z4 hatırlatıcı: lead'e bir kez bildirim" do
    incident = resolved(:major)
    travel 5.days

    assert_difference -> { incident.notifications.count }, 1 do
      Incident.remind_overdue_postmortems!
    end
    assert_equal @alice, incident.notifications.last.user
    assert_match(/postmortem/i, incident.notifications.last.message)

    travel 1.day
    assert_no_difference -> { incident.notifications.count } do
      Incident.remind_overdue_postmortems!
    end
  end

  # --- Z5: durum sayfası geçmişi ---

  test "Z5 halka açık çözülmüş olay 7 gün geçmişte görünür, 7 gün + 1 sn'de düşer" do
    incident = resolved(:major, public_impact: true)

    travel 7.days
    assert_includes Incident.recent_for_status_page, incident

    travel 1.second
    assert_not_includes Incident.recent_for_status_page, incident
  end

  test "Z5 kapanmış halka açık olay da 7 gün görünür (çözülme anına göre)" do
    incident = resolved(:minor, public_impact: true)
    travel 2.days
    incident.transition_to!(:closed, by: @alice)

    travel 4.days
    assert_includes Incident.recent_for_status_page, incident
    travel 1.day + 1.second
    assert_not_includes Incident.recent_for_status_page, incident
  end

  test "Z5 halka açık olmayan, reddedilmiş veya hâlâ aktif olay geçmişte görünmez" do
    internal = resolved(:major, public_impact: false)
    declined = declare(:major, public_impact: true).tap { |incident| incident.transition_to!(:declined, by: @alice) }
    active = declare(:major, public_impact: true)

    history = Incident.recent_for_status_page
    assert_not_includes history, internal
    assert_not_includes history, declined
    assert_not_includes history, active
    assert_includes Incident.public_facing.active, active
  end

  private
    def declare(severity, public_impact: false, communications: nil)
      Incident.declare!(service: services(:sis), title: "#{severity} olay", severity: severity,
                        public_impact: public_impact, lead: @alice, communications: communications, by: @manager)
    end

    def resolved(severity, public_impact: false)
      declare(severity, public_impact: public_impact).tap do |incident|
        incident.transition_to!(:investigating, by: @alice)
        if public_impact
          incident.publish_status_update!(public_status: :investigating, message: "İnceliyoruz.", by: @alice)
        end
        incident.transition_to!(:resolved, by: @alice)
      end
    end
end
