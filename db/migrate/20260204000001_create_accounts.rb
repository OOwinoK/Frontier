class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      # Account identification
      t.string :code, null: false, limit: 50
      t.string :name, null: false, limit: 255
      t.text :description
      
      # Account classification
      t.string :account_type, null: false, limit: 20
      t.string :currency, null: false, default: 'KES', limit: 3
      
      # Hierarchy support
      t.references :parent_account, foreign_key: { to_table: :accounts }, index: true
      
      # Denormalized balance for performance (scale: 4 for precision in interest calculations and multi-currency)
      t.decimal :current_balance, precision: 20, scale: 4, default: 0.0, null: false
      t.bigint :total_entries_count, default: 0, null: false
      t.datetime :balance_updated_at
      
      # Optimistic locking for concurrency control
      t.integer :lock_version, default: 0, null: false
      
      # Soft delete support
      t.boolean :active, default: true, null: false
      
      t.timestamps
    end
    
    # Indexes for performance
    add_index :accounts, :code, unique: true
    add_index :accounts, [:account_type, :currency]
    add_index :accounts, :active
    add_index :accounts, :lock_version
    
    # Check constraint for account types
    execute <<-SQL
      ALTER TABLE accounts
      ADD CONSTRAINT check_account_type
      CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'INCOME', 'EXPENSE'));
    SQL
    
    # Check constraint for currency codes (ISO 4217)
    execute <<-SQL
      ALTER TABLE accounts
      ADD CONSTRAINT check_currency_code
      CHECK (LENGTH(currency) = 3);
    SQL
  end
end
