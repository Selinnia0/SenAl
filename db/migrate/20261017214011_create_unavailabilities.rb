class CreateUnavailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :unavailabilities do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason

      t.timestamps
    end
    add_index :unavailabilities, %i[user_id starts_at ends_at]
  end
end
