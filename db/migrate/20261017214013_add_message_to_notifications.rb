class AddMessageToNotifications < ActiveRecord::Migration[8.1]
  def change
    # Boşluk raporu (Z5) bir olaya bağlı olmayan bildirimdir.
    change_column_null :notifications, :incident_id, true
    add_column :notifications, :message, :text
  end
end
