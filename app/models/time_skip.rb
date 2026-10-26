# Demo/test aracı: zaman kurallarını beklemeden görmek için "N dakika ileri sar".
#
# Gerçek saat değiştirilmez (global Time yaması yok). Bunun yerine açık alarmların ve olayların bütün
# zamanları N dakika geriye kaydırılır; her kural anında gerçek sınıf metotları çalışır:
#   Alert.escalate_due! (Z1), Alert.retrigger_stale! (Z7),
#   Incident.remind_overdue_updates! (Z3), Incident.remind_overdue_postmortems! (Z4).
# Z5 (durum sayfası geçmişi) bir scope olduğu için kaydırma tek başına yeterli.
# Sonuç, N dakika geçmiş gibidir ve zaman çizelgeleri tutarlı kalır. Nöbet rotasyonu, izinler ve
# akademik takvim gerçek saate göre hesaplanmaya devam eder.
class TimeSkip
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_MINUTES = 7 * 24 * 60 # Z4 (5 gün) ve Z5 (7 gün) de görülebilsin
  MAX_ITERATIONS = 10_000

  ALERT_TIMES = %i[triggered_at acknowledged_at escalate_at].freeze
  INCIDENT_TIMES = %i[declared_at last_update_at resolved_at closed_at
                      update_reminder_sent_at postmortem_reminder_sent_at].freeze

  attribute :minutes, :integer

  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }

  # Production'da yalnızca TIME_SKIP_ENABLED=1 ise açık (config/application.rb).
  def self.enabled?
    Rails.configuration.x.time_skip_enabled
  end

  # Oluşan kayıtları türüne göre döner: { "escalated" => 2, "notified" => 2, "incident_reminder" => 1 }
  def run!
    validate!

    Alert.transaction do
      last_event_id = AlertEvent.maximum(:id).to_i
      last_notification_id = Notification.maximum(:id).to_i
      remaining = minutes.minutes.to_i

      MAX_ITERATIONS.times do
        step = [ seconds_until_next_due, remaining ].compact.min
        if step.positive?
          shift_open_alerts!(step)
          shift_incidents!(step)
        end
        remaining -= step

        Alert.escalate_due!
        Alert.retrigger_stale!
        Incident.remind_overdue_updates!
        Incident.remind_overdue_postmortems!
        break if remaining <= 0
      end

      summary = AlertEvent.where(id: (last_event_id + 1)..).group(:kind).count
      reminders = Notification.where(id: (last_notification_id + 1)..).where.not(incident_id: nil).count
      reminders.positive? ? summary.merge("incident_reminder" => reminders) : summary
    end
  end

  private
    # Bir sonraki kural anına kalan saniye (yoksa nil).
    def seconds_until_next_due
      next_due = (alert_due_times + incident_due_times).min
      next_due && [ (next_due - Time.current).ceil, 0 ].max
    end

    def alert_due_times
      Alert.triggered.where.not(escalate_at: nil).pluck(:escalate_at) +
        Alert.acknowledged.includes(:service).map { |alert| alert.acknowledged_at + alert.service.ack_reset_minutes.minutes }
    end

    def incident_due_times
      update_due = Incident.active.where(update_reminder_sent_at: nil).filter_map(&:update_due_at)
      postmortem_due = Incident.resolved.where(postmortem_reminder_sent_at: nil).includes(:postmortem)
                               .reject { |incident| incident.postmortem&.published? }.filter_map(&:postmortem_due_at)
      update_due + postmortem_due
    end

    # update_columns bilinçli: bu bir zaman kaydırması, domain geçişi değil; doğrulama/callback yok.
    def shift_open_alerts!(seconds)
      Alert.not_resolved.includes(:alert_events, :notifications).find_each do |alert|
        shift_columns!(alert, ALERT_TIMES, seconds)
        alert.alert_events.each { |event| event.update_columns(occurred_at: event.occurred_at - seconds) }
        alert.notifications.each { |notification| notification.update_columns(created_at: notification.created_at - seconds) }
      end
    end

    # Bütün olaylar kayar: çözülmüş olaylar da kaymalı ki Z4 ve Z5 (geçmişten düşme) görülebilsin.
    def shift_incidents!(seconds)
      Incident.includes(:timeline_events, :status_page_updates, :notifications, :postmortem, :follow_ups)
              .find_each do |incident|
        shift_columns!(incident, INCIDENT_TIMES, seconds)
        incident.timeline_events.each { |event| event.update_columns(occurred_at: event.occurred_at - seconds) }
        incident.status_page_updates.each { |update| update.update_columns(published_at: update.published_at - seconds) }
        incident.notifications.each { |notification| notification.update_columns(created_at: notification.created_at - seconds) }
        shift_columns!(incident.postmortem, %i[published_at], seconds) if incident.postmortem
        incident.follow_ups.each { |follow_up| shift_columns!(follow_up, %i[completed_at], seconds) }
      end
    end

    # Yalnızca dolu zaman sütunlarını kaydırır. Hepsi boşsa (ör. tamamlanmamış takip görevi, taslak postmortem)
    # hiç güncelleme yapılmaz: update_columns({}) sütunsuz "UPDATE ... WHERE" üretip SQL hatası verir.
    def shift_columns!(record, attributes, seconds)
      changes = attributes.filter_map { |attribute| [ attribute, record[attribute] - seconds ] if record[attribute] }.to_h
      record.update_columns(changes) if changes.any?
    end
end
