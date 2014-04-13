class SimplifyUsers < ActiveRecord::Migration
  def up
    drop_table :users
    create_table :users do |t|
      # they're anonymous, so we don't know any additional info
      t.timestamps
    end
  end

  def down
    drop_table :users
    create_table :users do |t|
      t.string :first_name,          :limit => 30, :null => false
      t.string :last_name,           :limit => 30, :null => false
      t.string :email,               :limit => 90, :null => false
      t.string :google_plus_user_id, :limit => 30, :null => false
      t.timestamps
    end
  end
end
