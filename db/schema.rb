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

ActiveRecord::Schema[8.0].define(version: 2026_02_04_000005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_balance_snapshots", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "snapshot_date", null: false
    t.decimal "balance", precision: 20, scale: 4, null: false
    t.bigint "entries_count", default: 0, null: false
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "snapshot_date"], name: "index_snapshots_on_account_and_date", unique: true
    t.index ["account_id"], name: "index_account_balance_snapshots_on_account_id"
    t.index ["metadata"], name: "index_account_balance_snapshots_on_metadata", using: :gin
    t.index ["snapshot_date"], name: "index_account_balance_snapshots_on_snapshot_date"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "code", limit: 50, null: false
    t.string "name", limit: 255, null: false
    t.text "description"
    t.string "account_type", limit: 20, null: false
    t.string "currency", limit: 3, default: "KES", null: false
    t.bigint "parent_account_id"
    t.decimal "current_balance", precision: 20, scale: 4, default: "0.0", null: false
    t.bigint "total_entries_count", default: 0, null: false
    t.datetime "balance_updated_at"
    t.integer "lock_version", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_type", "currency"], name: "index_accounts_on_account_type_and_currency"
    t.index ["active"], name: "index_accounts_on_active"
    t.index ["code"], name: "index_accounts_on_code", unique: true
    t.index ["lock_version"], name: "index_accounts_on_lock_version"
    t.index ["parent_account_id"], name: "index_accounts_on_parent_account_id"
    t.check_constraint "account_type::text = ANY (ARRAY['ASSET'::character varying, 'LIABILITY'::character varying, 'EQUITY'::character varying, 'INCOME'::character varying, 'EXPENSE'::character varying]::text[])", name: "check_account_type"
    t.check_constraint "length(currency::text) = 3", name: "check_currency_code"
  end

  create_table "entries", primary_key: ["id", "created_at"], options: "PARTITION BY RANGE (created_at)", force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_entries_on_account_and_date"
    t.index ["created_at"], name: "index_entries_on_created_at"
    t.index ["transaction_id"], name: "index_entries_on_transaction_id"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_02", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_02_account"
    t.index ["created_at"], name: "entries_2026_02_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_02_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_03", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_03_account"
    t.index ["created_at"], name: "entries_2026_03_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_03_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_04", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_04_account"
    t.index ["created_at"], name: "entries_2026_04_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_04_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_05", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_05_account"
    t.index ["created_at"], name: "entries_2026_05_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_05_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_06", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_06_account"
    t.index ["created_at"], name: "entries_2026_06_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_06_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "entries_2026_07", primary_key: ["id", "created_at"], options: "INHERITS (entries)", force: :cascade do |t|
    t.bigint "id", default: -> { "nextval('entries_id_seq'::regclass)" }, null: false
    t.bigint "transaction_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 20, scale: 4
    t.decimal "credit", precision: 20, scale: 4
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "idx_entries_2026_07_account"
    t.index ["created_at"], name: "entries_2026_07_created_at_idx"
    t.index ["transaction_id"], name: "idx_entries_2026_07_transaction"
    t.check_constraint "debit IS NOT NULL AND credit IS NULL AND debit >= 0::numeric OR debit IS NULL AND credit IS NOT NULL AND credit >= 0::numeric", name: "check_debit_or_credit"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "idempotency_key", limit: 255, null: false
    t.text "description"
    t.datetime "posted_at", null: false
    t.string "status", limit: 20, default: "posted"
    t.string "external_reference", limit: 255
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_transactions_on_created_at"
    t.index ["external_reference"], name: "index_transactions_on_external_reference"
    t.index ["idempotency_key"], name: "index_transactions_on_idempotency_key", unique: true
    t.index ["metadata"], name: "index_transactions_on_metadata", using: :gin
    t.index ["posted_at", "status"], name: "index_transactions_on_posted_at_and_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'posted'::character varying, 'voided'::character varying, 'reversed'::character varying]::text[])", name: "check_transaction_status"
  end

  add_foreign_key "account_balance_snapshots", "accounts"
  add_foreign_key "accounts", "accounts", column: "parent_account_id"
  add_foreign_key "entries", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_02", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_02", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_03", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_03", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_04", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_04", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_05", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_05", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_06", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_06", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
  add_foreign_key "entries_2026_07", "accounts", name: "fk_entries_account_id", on_delete: :restrict
  add_foreign_key "entries_2026_07", "transactions", name: "fk_entries_transaction_id", on_delete: :cascade
end
