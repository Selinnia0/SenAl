class CreateTimelineEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :timeline_events do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.integer :kind, null: false
      t.text :body
      t.json :details, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    add_index :timeline_events, %i[incident_id occurred_at]
  end
end
