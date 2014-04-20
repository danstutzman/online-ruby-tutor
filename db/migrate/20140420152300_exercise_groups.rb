class ExerciseGroups < ActiveRecord::Migration
  def up
    add_column :exercises, :exercise_group_id,
      :integer, :null => false, :default => 0
    create_table :exercise_groups do |t|
      t.string :name, :null => false
      t.timestamps
    end
  end

  def down
    remove_column :exercises, :exercise_group_id
    drop_table :exercise_groups
  end
end
