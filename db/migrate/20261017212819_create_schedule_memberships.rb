class CreateScheduleMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_memberships do |t|
      t.references :schedule, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end
    add_index :schedule_memberships, %i[schedule_id user_id], unique: true
    add_index :schedule_memberships, %i[schedule_id position], unique: true
  end
end
