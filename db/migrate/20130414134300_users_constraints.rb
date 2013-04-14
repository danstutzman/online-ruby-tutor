class UsersConstraints < ActiveRecord::Migration
  def up
    change_column :users, :google_plus_user_id, :string, :null => true
    execute "update users set google_plus_user_id = null where google_plus_user_id = ''"
    add_index :users, :google_plus_user_id, :unique => true
    add_index :users, :email,               :unique => true
    add_column :users, :is_admin, :boolean, :null => false, :default => false
  end

  def down
    drop_index :users, :google_plus_user_id
    drop_index :users, :email
    execute "update users set google_plus_user_id = '' where google_plus_user_id is null"
    change_column :users, :google_plus_user_id, :string, :null => false
    remove_column :users, :is_admin
  end
end
