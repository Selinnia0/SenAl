module IncidentsHelper
  # Buton metni hedef duruma göre; geri dönüşler "Yeniden aç".
  TRANSITION_LABELS = {
    "investigating" => "İncelemeye al",
    "fixing" => "Düzeltmeye geç",
    "monitoring" => "İzlemeye al",
    "resolved" => "Çözüldü",
    "closed" => "Kapat",
    "declined" => "Reddet (yanlış alarm)"
  }.freeze

  TIMELINE_TONES = {
    "update" => :info, "status_change" => :accent, "role_change" => nil,
    "severity_change" => :critical, "reopened" => :critical
  }.freeze

  def transition_label(incident, to)
    return "Yeniden aç" if Incident::REOPENINGS.include?([ incident.status, to ])

    TRANSITION_LABELS.fetch(to)
  end

  # Tek kritik eylem vurgulu değil; ileri geçiş birincil, ret/yeniden açma ikincil.
  def transition_variant(incident, to)
    return :secondary if to == "declined" || Incident::REOPENINGS.include?([ incident.status, to ])

    :primary
  end

  # TimelineEvent → components/timeline öğesi.
  def timeline_items(incident)
    incident.timeline_events.includes(:user).map do |event|
      { time: event.occurred_at, author: event.user&.name || "Sistem", tone: TIMELINE_TONES[event.kind],
        kind_label: t("enums.timeline_event.kind.#{event.kind}"), body: timeline_body(event),
        badge: timeline_badge(event) }
    end
  end

  def timeline_body(event)
    details = event.details || {}
    case event.kind
    when "role_change"
      "#{t("enums.incident_role_assignment.role.#{details['role']}")}: #{details['to_user_name']}"
    when "severity_change"
      "#{t("enums.incident.severity.#{details['from']}")} → #{t("enums.incident.severity.#{details['to']}")}"
    else
      event.body
    end
  end

  def timeline_badge(event)
    return unless %w[status_change reopened].include?(event.kind) && event.details["to"]

    to = event.details["to"]
    badge(t("enums.incident.status.#{to}"), tone: ComponentsHelper::INCIDENT_STATUS_TONES.fetch(to))
  end

  def public_status_badge(status_page_update)
    tones = { "investigating" => :info, "identified" => :major, "monitoring" => :minor, "resolved" => :ok }
    badge(enum_label(status_page_update, :public_status), tone: tones.fetch(status_page_update.public_status))
  end

  def filter_pill(label, params_for, current)
    link_to label, incidents_path(params_for), class: "filter-pill", aria: { current: (current ? "true" : nil) }
  end
end
