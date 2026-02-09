class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      # Idempotency key for preventing duplicate transactions
      t.string :idempotency_key, null: false, limit: 255
      
      # Transaction details
      t.text :description
      t.datetime :posted_at, null: false
      t.string :status, default: 'posted', limit: 20
      
      # Optional reference to external system
      t.string :external_reference, limit: 255
      
      # Metadata for additional context
      t.jsonb :metadata, default: {}
      
      t.timestamps
    end
    
    # Indexes
    add_index :transactions, :idempotency_key, unique: true
    add_index :transactions, [:posted_at, :status]
    add_index :transactions, :created_at
    add_index :transactions, :external_reference
    
    # GIN index for JSONB metadata queries
    add_index :transactions, :metadata, using: :gin
    
    # Check constraint for status
    execute <<-SQL
      ALTER TABLE transactions
      ADD CONSTRAINT check_transaction_status
      CHECK (status IN ('pending', 'posted', 'voided', 'reversed'));
    SQL
  end
end
