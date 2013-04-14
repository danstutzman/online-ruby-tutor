class TaskIdNotExerciseNum < ActiveRecord::Migration
  def up
    # throw out the old exercise_nums rather than migrate them
    execute "delete from saves" 

    add_column :saves, :task_id, :string, :limit => 4
    remove_column :saves, :exercise_num
    add_index :saves, :task_id
  end

  def down
    # throw out the task_ids rather than migrate them
    execute "delete from saves" 

    add_column :saves, :exercise_num, :integer
    remove_column :saves, :task_id
  end
end
