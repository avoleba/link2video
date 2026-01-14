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

ActiveRecord::Schema[8.1].define(version: 2026_01_13_184244) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "video_requests", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.string "duration"
    t.text "error_message"
    t.integer "platform", default: 3, null: false
    t.datetime "processed_at"
    t.jsonb "result_data", default: {}
    t.integer "status", default: 0, null: false
    t.bigint "telegram_chat_id"
    t.bigint "telegram_message_id"
    t.string "thumbnail_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "video_url"
    t.index ["created_at"], name: "index_video_requests_on_created_at"
    t.index ["platform"], name: "index_video_requests_on_platform"
    t.index ["status"], name: "index_video_requests_on_status"
    t.index ["telegram_chat_id"], name: "index_video_requests_on_telegram_chat_id"
  end
end
