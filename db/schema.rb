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

ActiveRecord::Schema[8.1].define(version: 2026_10_17_212403) do
  create_table "escalation_levels", force: :cascade do |t|
    t.integer "escalation_policy_id", null: false
    t.integer "position", null: false
    t.integer "schedule_id", null: false
    t.integer "timeout_minutes", default: 5, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escalation_policy_id", "position"], name: "index_escalation_levels_on_escalation_policy_id_and_position", unique: true
    t.index ["escalation_policy_id"], name: "index_escalation_levels_on_escalation_policy_id"
    t.index ["schedule_id"], name: "index_escalation_levels_on_schedule_id"
  end

  create_table "escalation_policies", force: :cascade do |t|
    t.string "name", null: false
    t.integer "repeat_count", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incident_events", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "kind", null: false
    t.integer "user_id"
    t.json "details", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_incident_events_on_incident_id"
    t.index ["user_id"], name: "index_incident_events_on_user_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.integer "service_id", null: false
    t.string "title", null: false
    t.string "dedup_key", null: false
    t.integer "urgency", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "assignee_id"
    t.integer "current_level", default: 0, null: false
    t.integer "escalation_round", default: 0, null: false
    t.datetime "escalate_at"
    t.datetime "triggered_at", null: false
    t.datetime "acknowledged_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_incidents_on_assignee_id"
    t.index ["dedup_key"], name: "index_incidents_on_dedup_key"
    t.index ["escalate_at"], name: "index_incidents_on_escalate_at"
    t.index ["service_id", "dedup_key"], name: "index_incidents_on_service_id_and_dedup_key"
    t.index ["service_id"], name: "index_incidents_on_service_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "incident_id", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_notifications_on_incident_id"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "starts_at", null: false
    t.integer "rotation_days", default: 7, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "integration_key", null: false
    t.integer "escalation_policy_id", null: false
    t.integer "ack_reset_minutes", default: 240, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escalation_policy_id"], name: "index_services_on_escalation_policy_id"
    t.index ["integration_key"], name: "index_services_on_integration_key", unique: true
    t.index ["name"], name: "index_services_on_name", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.integer "role", default: 0, null: false
    t.integer "academic_role", default: 0, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "escalation_levels", "escalation_policies"
  add_foreign_key "escalation_levels", "schedules"
  add_foreign_key "incident_events", "incidents"
  add_foreign_key "incident_events", "users"
  add_foreign_key "incidents", "services"
  add_foreign_key "incidents", "users", column: "assignee_id"
  add_foreign_key "notifications", "incidents"
  add_foreign_key "notifications", "users"
  add_foreign_key "services", "escalation_policies"
  add_foreign_key "sessions", "users"
end
