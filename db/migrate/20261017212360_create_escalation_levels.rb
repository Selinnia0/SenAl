class CreateEscalationLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :escalation_levels do |t|
      t.references :escalation_policy, null: false, foreign_key: true
      t.integer :position, null: false
      t.references :schedule, null: false, foreign_key: true
      t.integer :timeout_minutes, null: false, default: 5

      t.timestamps
    end
    add_index :escalation_levels, %i[escalation_policy_id position], unique: true
  end
end
