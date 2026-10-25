module AlertsHelper
  ALERT_TIMELINE_TONES = {
    "triggered" => :critical, "notified" => :info, "acknowledged" => :accent, "resolved" => :ok,
    "escalated" => :critical, "retriggered" => :critical, "gap_skipped" => nil, "deduplicated" => nil,
    "escalation_exhausted" => :critical
  }.freeze

  # AlertEvent → components/timeline öğesi.
  def alert_timeline_items(alert)
    alert.alert_events.includes(:user).map do |event|
      { time: event.occurred_at, author: event.user&.name || "Sistem", tone: ALERT_TIMELINE_TONES[event.kind],
        kind_label: event_label(event), body: event_description(event) }
    end
  end

  def alert_filter_pill(label, params_for, current)
    link_to label, alerts_path(params_for), class: "filter-pill", aria: { current: (current ? "true" : nil) }
  end
end
