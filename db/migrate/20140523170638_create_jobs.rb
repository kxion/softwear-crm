class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.string :name
      t.text :description

      t.belongs_to :order

      t.datetime :deleted_at
      t.timestamps
    end
  end
end
