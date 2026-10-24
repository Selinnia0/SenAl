# Halka açık durum sayfasının verisi. Yalnızca public_impact olaylar; iç zaman çizelgesi notları değil,
# yalnızca yayınlanmış durum sayfası güncellemeleri gösterilir.
class StatusPage
  Row = Data.define(:service, :state, :days)

  DAYS = 7
  STATE_RANK = { operational: 0, partial: 1, major: 2 }.freeze

  def initialize(now: Time.current)
    @now = now
  end

  def active_incidents
    @active_incidents ||= Incident.public_facing.active.includes(:service, :status_page_updates).order(declared_at: :desc).to_a
  end

  # Z5: çözülmüş halka açık olaylar 7 gün görünür.
  def history
    @history ||= Incident.recent_for_status_page.includes(:service, :status_page_updates).order(resolved_at: :desc).to_a
  end

  def operational?
    active_incidents.empty?
  end

  def headline
    operational? ? "Tüm sistemler çalışıyor" : "Şu an #{active_incidents.size} aktif olay var"
  end

  def rows
    Service.order(:name).map do |service|
      current = active_incidents.select { |incident| incident.service_id == service.id }
      Row.new(service: service, state: worst_state(current), days: days_for(service))
    end
  end

  # Olay critical ise büyük kesinti, değilse kısmi kesinti.
  def self.state_for(incident)
    incident.critical? ? :major : :partial
  end

  private
    def worst_state(incidents)
      incidents.map { |incident| self.class.state_for(incident) }.max_by { |state| STATE_RANK[state] } || :operational
    end

    # Son 7 gün (Istanbul günleri, eskiden yeniye): o gün açık olan halka açık olayların en kötüsü.
    def days_for(service)
      first_day = @now.to_date - (DAYS - 1)
      window_start = first_day.in_time_zone
      incidents = Incident.public_facing.where(service: service).where.not(status: :declined)
                          .where(declared_at: ..@now)
                          .where("incidents.resolved_at IS NULL OR incidents.resolved_at >= ?", window_start).to_a

      (first_day..@now.to_date).map do |day|
        day_start, day_end = day.in_time_zone, day.in_time_zone.end_of_day
        overlapping = incidents.select { |incident| incident.declared_at <= day_end && (incident.resolved_at || @now) >= day_start }
        worst_state(overlapping)
      end
    end
end
