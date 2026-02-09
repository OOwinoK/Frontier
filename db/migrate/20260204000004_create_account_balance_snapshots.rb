class CreateAccountBalanceSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :account_balance_snapshots do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.date :snapshot_date, null: false
      t.decimal :balance, precision: 20, scale: 4, null: false
      t.bigint :entries_count, null: false, default: 0
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    # Unique constraint: one snapshot per account per date
    add_index :account_balance_snapshots, [:account_id, :snapshot_date], 
              unique: true, 
              name: 'index_snapshots_on_account_and_date'
    
    # Index for date-based queries
    add_index :account_balance_snapshots, :snapshot_date
    
    # GIN index for metadata
    add_index :account_balance_snapshots, :metadata, using: :gin
  end
end
