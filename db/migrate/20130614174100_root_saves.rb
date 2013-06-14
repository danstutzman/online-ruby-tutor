class RootSaves < ActiveRecord::Migration
  def up
    create_table :root_saves do |t|
      t.integer :user_id,      :null => true
      t.boolean :is_current,   :null => false
      t.text    :code,         :null => false
      t.timestamps
    end
  end

  def down
    drop_table :root_saves
  end
end
