# PostgreSQL'de rename_column kısıt adını değiştirmez: notifications.alert_id'nin yabancı anahtarı hâlâ
# eski "notifications.incident_id" adından türetilmiş fk_rails_... adını taşır. Yeni
# notifications.incident_id anahtarı (AddIncidentIdToNotifications) aynı adı üretip çakışır
# (PG::DuplicateObject). Kısıtı silip yeniden eklemek ona alert_id'den türetilen adı verir.
class RenameNotificationsAlertForeignKey < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :notifications, :alerts, column: :alert_id
    add_foreign_key :notifications, :alerts, column: :alert_id
  end
end
