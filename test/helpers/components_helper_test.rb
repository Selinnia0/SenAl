require "test_helper"

class ComponentsHelperTest < ActionView::TestCase
  include ApplicationHelper # enum_label; görünümlerde bütün helper'lar zaten yüklü
  test "btn_class türleri ve geçersiz tür" do
    assert_equal "btn btn--primary", btn_class(:primary)
    assert_equal "btn btn--accent btn--sm btn--block", btn_class(:accent, size: :sm, block: true)
    assert_raises(ArgumentError) { btn_class(:danger) }
  end

  test "her severity ve her olay/alarm durumunun bir tonu var (renk + metin)" do
    assert_equal Incident.severities.keys.sort, SEVERITY_TONES.keys.sort
    assert_equal Incident.statuses.keys.sort, INCIDENT_STATUS_TONES.keys.sort
    assert_equal Alert.statuses.keys.sort, ALERT_STATUS_TONES.keys.sort
    (SEVERITY_TONES.values + INCIDENT_STATUS_TONES.values + ALERT_STATUS_TONES.values).each do |tone|
      assert_includes BADGE_TONES, tone
    end
  end

  test "severity rozeti metin içerir, yalnızca renk değil" do
    html = severity_badge(incidents(:triage_critical))
    assert_includes html, "badge--critical"
    assert_includes html, "Kritik"
  end

  test "incident_ref INC-042 biçiminde" do
    incident = Incident.new(id: 42)
    assert_equal "INC-042", incident_ref(incident)
  end

  test "mono_time 14:32 UTC+3 biçiminde" do
    html = mono_time(Time.zone.parse("2026-10-19 14:32"))
    assert_includes html, "14:32 UTC+3"
    assert_includes html, %(class="mono")
  end
end
