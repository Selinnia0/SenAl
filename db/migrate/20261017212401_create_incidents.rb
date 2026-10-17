class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.references :service, null: false, foreign_key: true
      t.string :title, null: false
      t.string :dedup_key, null: false
      t.integer :urgency, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.integer :current_level, null: false, default: 0
      t.integer :escalation_round, null: false, default: 0
      t.datetime :escalate_at
      t.datetime :triggered_at, null: false
      t.datetime :acknowledged_at
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :incidents, :dedup_key
    add_index :incidents, %i[service_id dedup_key]
    add_index :incidents, :escalate_at
  end
end
