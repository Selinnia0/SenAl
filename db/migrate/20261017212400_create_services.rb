class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :integration_key, null: false
      t.references :escalation_policy, null: false, foreign_key: true
      t.integer :ack_reset_minutes, null: false, default: 240

      t.timestamps
    end
    add_index :services, :name, unique: true
    add_index :services, :integration_key, unique: true
  end
end
