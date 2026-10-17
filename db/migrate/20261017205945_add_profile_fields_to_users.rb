class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # SQLite NOT NULL sütun eklerken varsayılan ister; boşluk kontrolü modelde.
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :role, :integer, null: false, default: 0
    add_column :users, :academic_role, :integer, null: false, default: 0
  end
end
