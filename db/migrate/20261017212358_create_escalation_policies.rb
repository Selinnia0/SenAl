class CreateEscalationPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :escalation_policies do |t|
      t.string :name, null: false
      t.integer :repeat_count, null: false, default: 1

      t.timestamps
    end
  end
end
