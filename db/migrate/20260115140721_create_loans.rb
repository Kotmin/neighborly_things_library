class CreateLoans < ActiveRecord::Migration[8.1]
  def change
    create_table :loans do |t|
      t.references :item, null: false, foreign_key: true
      t.string :borrower_name, null: false
      t.datetime :borrowed_at, null: false
      t.datetime :returned_at

      t.timestamps
    end

    add_index :loans, :returned_at
  end
end
