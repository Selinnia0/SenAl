# v2 response katmanı: ilan edilen olay (incident.io ilhamlı). Alert'ten ya da elle ilan edilir.
class CreateResponseIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.references :service, null: false, foreign_key: true
      t.references :alert, null: true, foreign_key: true
      t.string :title, null: false
      t.text :summary
      t.integer :severity, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.boolean :public_impact, null: false, default: false
      t.datetime :declared_at, null: false
      t.datetime :last_update_at, null: false
      t.datetime :resolved_at
      t.datetime :closed_at
      t.datetime :update_reminder_sent_at
      t.datetime :postmortem_reminder_sent_at

      t.timestamps
    end
    add_index :incidents, :status
    add_index :incidents, :last_update_at
    add_index :incidents, :resolved_at
  end
end
