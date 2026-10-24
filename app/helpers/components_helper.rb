# Tasarım sistemi yardımcıları. Görsel bileşenler app/views/components/ altında partial; burada yalnızca
# sınıf adları, ton eşlemeleri ve küçük biçimlendiriciler var.
module ComponentsHelper
  BUTTON_VARIANTS = %i[primary accent secondary ghost].freeze
  BADGE_TONES = %i[critical major minor ok info accent neutral].freeze

  SEVERITY_TONES = { "critical" => :critical, "major" => :major, "minor" => :minor }.freeze
  INCIDENT_STATUS_TONES = {
    "triage" => :accent, "investigating" => :info, "fixing" => :major, "monitoring" => :minor,
    "resolved" => :ok, "closed" => :neutral, "declined" => :neutral
  }.freeze
  ALERT_STATUS_TONES = { "triggered" => :critical, "acknowledged" => :major, "resolved" => :ok }.freeze

  def btn_class(variant = :secondary, size: nil, block: false)
    raise ArgumentError, "Bilinmeyen buton türü: #{variant}" unless BUTTON_VARIANTS.include?(variant.to_sym)

    [ "btn", "btn--#{variant}", ("btn--#{size}" if size), ("btn--block" if block) ].compact.join(" ")
  end

  def badge(label, tone: :neutral, dot: true)
    render "components/badge", label: label, tone: tone, dot: dot
  end

  def severity_badge(incident)
    badge(enum_label(incident, :severity), tone: SEVERITY_TONES.fetch(incident.severity))
  end

  def incident_status_badge(incident)
    badge(enum_label(incident, :status), tone: INCIDENT_STATUS_TONES.fetch(incident.status))
  end

  def alert_status_badge(alert)
    badge(enum_label(alert, :status), tone: ALERT_STATUS_TONES.fetch(alert.status))
  end

  # INC-042
  def incident_ref(incident)
    format("INC-%03d", incident.id)
  end

  # 14:32 UTC+3 (mono etiket); tam tarih title'da.
  def mono_time(time)
    return unless time

    local = time.in_time_zone
    offset_hours = local.utc_offset / 3600
    label = "#{local.strftime('%H:%M')} UTC#{offset_hours.negative? ? '-' : '+'}#{offset_hours.abs}"
    tag.time(label, datetime: local.iso8601, title: l(local, format: :compact), class: "mono")
  end

  def sidebar_link(label, path, count: nil)
    content = count ? safe_join([ "#{label} ", tag.span("(#{count})", class: "sidebar__count") ]) : label
    link_to content, path, class: "sidebar__link", aria: { current: (current_page?(path) ? "page" : nil) }
  end

  # Henüz ekranı olmayan bölüm (Faz E): menüde yeri görünsün ama tıklanamasın.
  def sidebar_soon(label)
    tag.span(safe_join([ label, tag.span("yakında", class: "sidebar__count") ]),
             class: "sidebar__link sidebar__link--soon", aria: { disabled: true })
  end
end
