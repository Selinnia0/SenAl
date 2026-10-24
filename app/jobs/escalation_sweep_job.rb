# Her dakika çalışır (config/recurring.yml). Mantık yok: yalnızca sınıf metotlarını çağırır.
# Alert: Z1 eskalasyon, Z7 bayatlama. Incident: Z3 güncelleme ve Z4 postmortem hatırlatıcıları.
class EscalationSweepJob < ApplicationJob
  queue_as :default

  def perform
    Alert.escalate_due!
    Alert.retrigger_stale!
    Incident.remind_overdue_updates!
    Incident.remind_overdue_postmortems!
  end
end
