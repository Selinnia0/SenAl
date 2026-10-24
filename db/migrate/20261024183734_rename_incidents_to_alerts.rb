# v2: PagerDuty mantığındaki olay (triggered → acknowledged → resolved) artık on-call katmanının
# "Alert"i. Yeni "Incident" response katmanıdır (ayrı migration). Davranış değişmez.
class RenameIncidentsToAlerts < ActiveRecord::Migration[8.1]
  def change
    rename_table :incidents, :alerts
    rename_table :incident_events, :alert_events
    rename_column :alert_events, :incident_id, :alert_id
    rename_column :notifications, :incident_id, :alert_id
    # Özel adlı indeks: rename_table yalnızca varsayılan adlı indeksleri yeniden adlandırır.
    rename_index :alerts, "index_incidents_on_open_dedup_key", "index_alerts_on_open_dedup_key"
  end
end
