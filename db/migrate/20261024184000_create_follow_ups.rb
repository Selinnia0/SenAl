class CreateFollowUps < ActiveRecord::Migration[8.1]
  def change
    create_table :follow_ups do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.date :due_on
      t.datetime :completed_at

      t.timestamps
    end
  end
end
