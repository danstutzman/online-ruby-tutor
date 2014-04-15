class TaskIdSubstring < ActiveRecord::Migration
  def up
    add_column :exercises, :task_id_substring, :string
    add_index :exercises, :task_id_substring
  end

  def down
    remove_column :exercises, :task_id_substring
  end
end
