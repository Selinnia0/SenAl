# Demo/test aracı: eskalasyonu (5 dk) ve bayatlamayı (4 saat) beklemeden görmek için "N dakika ileri sar".
#
# Gerçek saat değiştirilmez (global Time yaması yok). Bunun yerine açık olayların bütün zamanları
# N dakika geriye kaydırılır; her eskalasyon/bayatlama anında gerçek Incident.escalate_due! ve
# Incident.retrigger_stale! çalışır. Sonuç, N dakika geçmiş gibidir ve zaman çizelgesi tutarlı kalır.
# Nöbet rotasyonu gerçek saate göre hesaplanmaya devam eder.
class TimeSkip
  include ActiveModel::Model
  include ActiveModel::Attributes

  MAX_MINUTES = 24 * 60
  MAX_ITERATIONS = 10_000

  attribute :minutes, :integer

  validates :minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MINUTES }

  # Production'da yalnızca TIME_SKIP_ENABLED=1 ise açık (config/application.rb).
  def self.enabled?
    Rails.configuration.x.time_skip_enabled
  end

  # Oluşan zaman çizelgesi kayıtlarını türüne göre döner: { "escalated" => 2, "notified" => 2, ... }
  def run!
    validate!

    Incident.transaction do
      last_event_id = IncidentEvent.maximum(:id).to_i
      remaining = minutes.minutes.to_i

      MAX_ITERATIONS.times do
        step = [ seconds_until_next_due, remaining ].compact.min
        shift_open_incidents!(step) if step.positive?
        remaining -= step

        Incident.escalate_due!
        Incident.retrigger_stale!
        break if remaining <= 0
      end

      IncidentEvent.where(id: (last_event_id + 1)..).group(:kind).count
    end
  end

  private
    # Bir sonraki eskalasyon veya bayatlama anına kalan saniye (yoksa nil).
    def seconds_until_next_due
      due_times = Incident.triggered.where.not(escalate_at: nil).pluck(:escalate_at)
      due_times += Incident.acknowledged.includes(:service).map do |incident|
        incident.acknowledged_at + incident.service.ack_reset_minutes.minutes
      end

      next_due = due_times.min
      next_due && [ (next_due - Time.current).ceil, 0 ].max
    end

    # update_columns bilinçli: bu bir zaman kaydırması, domain geçişi değil; doğrulama/callback yok.
    def shift_open_incidents!(seconds)
      Incident.not_resolved.includes(:incident_events, :notifications).find_each do |incident|
        incident.update_columns(shifted(incident, %i[triggered_at acknowledged_at escalate_at], seconds))
        incident.incident_events.each { |event| event.update_columns(occurred_at: event.occurred_at - seconds) }
        incident.notifications.each { |notification| notification.update_columns(created_at: notification.created_at - seconds) }
      end
    end

    def shifted(record, attributes, seconds)
      attributes.filter_map { |attribute| [ attribute, record[attribute] - seconds ] if record[attribute] }.to_h
    end
end
