# Response katmanı hatırlatıcıları (Z3/Z4) olaya bağlı bildirim üretir.
class AddIncidentIdToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :incident, null: true, foreign_key: true
  end
end
