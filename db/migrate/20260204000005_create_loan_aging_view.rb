class CreateLoanAgingView < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      CREATE MATERIALIZED VIEW loan_aging_report AS
      WITH loan_accounts AS (
        SELECT 
          a.id as loan_account_id,
          a.code as loan_code,
          a.name as borrower_name,
          a.current_balance as outstanding_balance,
          a.created_at as disbursement_date,
          MAX(CASE WHEN e.credit > 0 THEN e.created_at END) as last_payment_date,
          COALESCE(
            CURRENT_DATE - MAX(CASE WHEN e.credit > 0 THEN e.created_at END)::date,
            CURRENT_DATE - a.created_at::date
          ) as days_since_last_payment
        FROM accounts a
        LEFT JOIN entries e ON e.account_id = a.id
        WHERE a.account_type = 'ASSET' 
          AND a.code LIKE 'LOAN-%'
          AND a.current_balance > 0
          AND a.active = true
        GROUP BY a.id, a.code, a.name, a.current_balance, a.created_at
      )
      SELECT 
        loan_account_id,
        loan_code,
        borrower_name,
        outstanding_balance,
        disbursement_date,
        last_payment_date,
        days_since_last_payment,
        CASE 
          WHEN days_since_last_payment <= 29 THEN 'current'
          WHEN days_since_last_payment BETWEEN 30 AND 59 THEN '30_59_days'
          WHEN days_since_last_payment BETWEEN 60 AND 89 THEN '60_89_days'
          ELSE '90_plus_days'
        END as aging_bucket
      FROM loan_accounts;
      
      -- Create indexes on materialized view
      CREATE UNIQUE INDEX ON loan_aging_report (loan_account_id);
      CREATE INDEX ON loan_aging_report (aging_bucket);
      CREATE INDEX ON loan_aging_report (outstanding_balance);
      CREATE INDEX ON loan_aging_report (days_since_last_payment);
    SQL
  end
  
  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS loan_aging_report;"
  end
end