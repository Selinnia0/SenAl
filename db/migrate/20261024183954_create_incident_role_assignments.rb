class CreateIncidentRoleAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :incident_role_assignments do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end
    add_index :incident_role_assignments, %i[incident_id role], unique: true
  end
end
