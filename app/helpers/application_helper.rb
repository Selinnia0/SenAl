module ApplicationHelper
  def format_time(time)
    time && l(time.in_time_zone, format: :compact)
  end

  def format_date(date)
    date && l(date, format: :compact)
  end

  # enum değerinin Türkçe etiketi: enum_label(alert, :status) → "Tetiklendi"
  def enum_label(record, attribute)
    value = record.public_send(attribute)
    t("enums.#{record.model_name.i18n_key}.#{attribute}.#{value}", default: value.to_s.humanize)
  end


  def event_label(event)
    t("enums.alert_event.kind.#{event.kind}", default: event.kind)
  end

  # Zaman çizelgesindeki bir kaydın açıklaması.
  def event_description(event)
    details = event.details || {}
    case event.kind
    when "notified"
      "#{details['user_name']} bilgilendirildi (seviye #{details['level'].to_i + 1}, tur #{details['round'].to_i + 1})"
    when "escalated"
      "Seviye #{details['from_level'].to_i + 1} → #{details['to_level'].to_i + 1} (tur #{details['to_round'].to_i + 1})"
    when "gap_skipped"
      "Seviye #{details['level'].to_i + 1} boş: #{details['schedule_name']} takviminde müsait nöbetçi yok"
    when "deduplicated"
      "Tekrar eden alarm: #{details['summary']}"
    when "escalation_exhausted"
      "Eskalasyon turları tükendi; yöneticiler bilgilendirildi"
    end
  end
end
