# Her dakika çalışır (config/recurring.yml). Mantık yok: yalnızca Incident sınıf metotlarını çağırır.
class EscalationSweepJob < ApplicationJob
  queue_as :default

  def perform
    Incident.escalate_due!
    Incident.retrigger_stale!
  end
end
