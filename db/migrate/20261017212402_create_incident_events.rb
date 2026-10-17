class CreateIncidentEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :incident_events do |t|
      t.references :incident, null: false, foreign_key: true
      t.string :kind, null: false
      t.references :user, null: true, foreign_key: true
      t.json :details, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
  end
end
