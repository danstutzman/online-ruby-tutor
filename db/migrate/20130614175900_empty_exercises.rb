class EmptyExercises < ActiveRecord::Migration
  def up
    create_table :exercises do |t|
      t.string :task_id
      t.text :yaml
      t.timestamps
    end
  end

  def down
    drop_table :exercises
  end
end
