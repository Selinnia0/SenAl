class CreateStatusPageUpdates < ActiveRecord::Migration[8.1]
  def change
    create_table :status_page_updates do |t|
      t.references :incident, null: false, foreign_key: true
      t.integer :public_status, null: false
      t.text :message, null: false
      t.datetime :published_at, null: false

      t.timestamps
    end
    add_index :status_page_updates, %i[incident_id published_at]
  end
end
