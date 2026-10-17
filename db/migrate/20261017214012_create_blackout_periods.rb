class CreateBlackoutPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :blackout_periods do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.integer :applies_to, null: false, default: 0
      t.date :starts_on, null: false
      t.date :ends_on, null: false

      t.timestamps
    end
    add_index :blackout_periods, %i[starts_on ends_on]
  end
end
