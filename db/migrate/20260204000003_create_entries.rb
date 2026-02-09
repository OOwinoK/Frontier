# db/migrate/20260204000003_create_entries.rb
class CreateEntries < ActiveRecord::Migration[8.0]
  def up
    # 1. Create the partitioned parent table
    # DECIMAL(20,4) ensures UGX/KES precision and accurate interest accruals
    execute <<-SQL
      CREATE TABLE entries (
        id BIGSERIAL,
        transaction_id BIGINT NOT NULL,
        account_id BIGINT NOT NULL,
        debit DECIMAL(20,4),
        credit DECIMAL(20,4),
        description TEXT,
        created_at TIMESTAMP(6) NOT NULL,
        updated_at TIMESTAMP(6) NOT NULL,
        PRIMARY KEY (id, created_at)
      ) PARTITION BY RANGE (created_at);
    SQL

    # 2. Create the partitions
    create_monthly_partitions(Date.current, 6)

    # 3. Add Foreign Keys and Integrity Constraints via raw SQL
    execute <<-SQL
      ALTER TABLE entries
      ADD CONSTRAINT fk_entries_transaction_id
      FOREIGN KEY (transaction_id)
      REFERENCES transactions(id)
      ON DELETE CASCADE;
      
      ALTER TABLE entries
      ADD CONSTRAINT fk_entries_account_id
      FOREIGN KEY (account_id)
      REFERENCES accounts(id)
      ON DELETE RESTRICT;

      ALTER TABLE entries
      ADD CONSTRAINT check_debit_or_credit
      CHECK (
        (debit IS NOT NULL AND credit IS NULL AND debit >= 0) OR
        (debit IS NULL AND credit IS NOT NULL AND credit >= 0)
      );
    SQL

    # 4. Create indexes on parent via raw SQL
    # We avoid Rails 'add_index' because it attempts to manage partitioned objects incorrectly
    execute "CREATE INDEX index_entries_on_account_and_date ON entries (account_id, created_at);"
    execute "CREATE INDEX index_entries_on_transaction_id ON entries (transaction_id);"
    execute "CREATE INDEX index_entries_on_created_at ON entries (created_at);"
  end

  def down
    # Dropping the parent table automatically drops all partitions and indexes
    drop_table :entries
  end

  private

  def create_monthly_partitions(start_date, num_months)
    num_months.times do |i|
      partition_date = start_date.beginning_of_month + i.months
      partition_name = "entries_#{partition_date.strftime('%Y_%m')}"
      start_range = partition_date.beginning_of_month
      end_range = (partition_date + 1.month).beginning_of_month
      
      execute <<-SQL
        CREATE TABLE IF NOT EXISTS #{partition_name}
        PARTITION OF entries
        FOR VALUES FROM ('#{start_range}') TO ('#{end_range}');
      SQL
    end
  end
end