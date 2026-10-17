class CreateSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :schedules do |t|
      t.string :name, null: false
      t.datetime :starts_at, null: false
      t.integer :rotation_days, null: false, default: 7

      t.timestamps
    end
  end
end
