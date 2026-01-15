class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.text :description
      t.string :condition, null: false
      t.boolean :available, null: false, default: true

      t.timestamps
    end

    add_index :items, :available
  end
end
