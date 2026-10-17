class CreateOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :overrides do |t|
      t.references :schedule, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.timestamps
    end
    add_index :overrides, %i[schedule_id starts_at ends_at]
  end
end
