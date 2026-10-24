# Her dakika çalışır (config/recurring.yml). Mantık yok: yalnızca Alert sınıf metotlarını çağırır.
class EscalationSweepJob < ApplicationJob
  queue_as :default

  def perform
    Alert.escalate_due!
    Alert.retrigger_stale!
  end
end
