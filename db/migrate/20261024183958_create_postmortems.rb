class CreatePostmortems < ActiveRecord::Migration[8.1]
  def change
    create_table :postmortems do |t|
      t.references :incident, null: false, foreign_key: true, index: { unique: true }
      t.text :body
      t.date :due_on
      t.datetime :published_at

      t.timestamps
    end
  end
end
