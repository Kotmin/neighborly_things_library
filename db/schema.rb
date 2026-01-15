# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_15_140721) do
  create_table "items", force: :cascade do |t|
    t.boolean "available", default: true, null: false
    t.string "category", null: false
    t.string "condition", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["available"], name: "index_items_on_available"
  end

  create_table "loans", force: :cascade do |t|
    t.datetime "borrowed_at", null: false
    t.string "borrower_name", null: false
    t.datetime "created_at", null: false
    t.integer "item_id", null: false
    t.datetime "returned_at"
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_loans_on_item_id"
    t.index ["returned_at"], name: "index_loans_on_returned_at"
  end

  add_foreign_key "loans", "items"
end
