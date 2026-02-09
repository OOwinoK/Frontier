# app/queries/trial_balance_query.rb
#
# Query class for generating trial balance reports
# Trial Balance: Sum of all debits must equal sum of all credits

class TrialBalanceQuery
  class TrialBalanceError < StandardError; end
  
  class << self
    # Generate trial balance report
    def generate(as_of: Date.current, currency: nil)
      # Use Redis cache for current day
      if as_of == Date.current && currency.nil?
        cached = fetch_from_cache
        return cached if cached
      end
      
      # Generate trial balance
      trial_balance = if as_of == Date.current
        current_trial_balance(currency)
      else
        historical_trial_balance(as_of, currency)
      end
      
      # Verify it balances
      verify_balance!(trial_balance)
      
      # Cache if current and no currency filter
      cache_trial_balance(trial_balance) if as_of == Date.current && currency.nil?
      
      trial_balance
    end
    
    private
    
    def current_trial_balance(currency)
      scope = Account.active.where.not(current_balance: 0)
      scope = scope.where(currency: currency) if currency
      
      accounts = scope.select(:id, :code, :name, :account_type, :currency, :current_balance)
                     .order(:account_type, :code)
      
      group_by_type(accounts.map do |account|
        # Determine debit/credit based on account type and balance
        debit, credit = calculate_debit_credit(account.account_type, account.current_balance)
        
        {
          account_id: account.id,
          account_code: account.code,
          account_name: account.name,
          account_type: account.account_type,
          currency: account.currency,
          debit: debit,
          credit: credit
        }
      end, currency)
    end
    
    def calculate_debit_credit(account_type, balance)
      # ASSET & EXPENSE: Normal Debit Balance
      # - Positive balance = Debit
      # - Negative balance = Credit
      #
      # LIABILITY, EQUITY, INCOME: Normal Credit Balance  
      # - Positive balance = Credit
      # - Negative balance = Debit
      
      if ['ASSET', 'EXPENSE'].include?(account_type)
        # Debit normal accounts
        if balance > 0
          [balance.to_f, 0]  # Debit
        else
          [0, balance.abs.to_f]  # Credit
        end
      else
        # Credit normal accounts (LIABILITY, EQUITY, INCOME)
        if balance > 0
          [0, balance.to_f]  # Credit
        else
          [balance.abs.to_f, 0]  # Debit
        end
      end
    end
    
    def historical_trial_balance(as_of_date, currency)
      # Use SQL for efficient historical calculation
      sql = <<-SQL
        WITH account_balances AS (
          SELECT 
            a.id as account_id,
            a.code as account_code,
            a.name as account_name,
            a.account_type,
            a.currency,
            COALESCE(
              (SELECT balance 
               FROM account_balance_snapshots 
               WHERE account_id = a.id 
                 AND snapshot_date <= :as_of_date
               ORDER BY snapshot_date DESC 
               LIMIT 1), 
              0
            ) + COALESCE(
              (SELECT SUM(COALESCE(debit, 0) - COALESCE(credit, 0))
               FROM entries
               WHERE account_id = a.id
                 AND created_at > (
                   SELECT COALESCE(MAX(snapshot_date), '1970-01-01'::date)
                   FROM account_balance_snapshots
                   WHERE account_id = a.id
                     AND snapshot_date <= :as_of_date
                 )
                 AND created_at <= :as_of_date
              ),
              0
            ) as balance
          FROM accounts a
          WHERE a.active = true
            #{currency ? "AND a.currency = :currency" : ""}
        )
        SELECT 
          account_id,
          account_code,
          account_name,
          account_type,
          currency,
          -- Apply normal balance rules
          CASE 
            WHEN account_type IN ('ASSET', 'EXPENSE') THEN
              CASE WHEN balance > 0 THEN balance ELSE 0 END
            ELSE
              CASE WHEN balance < 0 THEN ABS(balance) ELSE 0 END
          END as debit,
          CASE 
            WHEN account_type IN ('ASSET', 'EXPENSE') THEN
              CASE WHEN balance < 0 THEN ABS(balance) ELSE 0 END
            ELSE
              CASE WHEN balance > 0 THEN balance ELSE 0 END
          END as credit
        FROM account_balances
        WHERE balance != 0
        ORDER BY account_type, account_code
      SQL
      
      binds = { as_of_date: as_of_date.end_of_day }
      binds[:currency] = currency if currency
      
      results = ActiveRecord::Base.connection.exec_query(sql, 'TrialBalance', binds)
      
      group_by_type(results.to_a.map(&:symbolize_keys), currency)
    end
    
    def group_by_type(accounts, currency)
      grouped = accounts.group_by { |a| a[:account_type] }
      
      accounts_by_type = Account::TYPES.map do |type|
        type_accounts = grouped[type] || []
        {
          account_type: type,
          accounts: type_accounts,
          total_debit: type_accounts.sum { |a| a[:debit] },
          total_credit: type_accounts.sum { |a| a[:credit] }
        }
      end
      
      total_debits = accounts.sum { |a| a[:debit] }
      total_credits = accounts.sum { |a| a[:credit] }
      
      {
        as_of: Date.current,
        currency: currency,
        accounts_by_type: accounts_by_type,
        total_debits: total_debits,
        total_credits: total_credits,
        difference: total_debits - total_credits,
        balanced: (total_debits - total_credits).abs < 0.01,
        generated_at: Time.current
      }
    end
    
    def verify_balance!(trial_balance)
      difference = trial_balance[:difference].abs
      
      if difference > 0.01 # Allow for rounding
        raise TrialBalanceError, 
              "Trial balance doesn't balance! Difference: #{difference}"
      end
    end
    
    def fetch_from_cache
      return nil unless defined?(REDIS) && REDIS
      
      cached = REDIS.get('trial_balance:current')
      JSON.parse(cached, symbolize_names: true) if cached
    rescue Redis::BaseError, JSON::ParserError
      nil
    end
    
    def cache_trial_balance(trial_balance)
      return unless defined?(REDIS) && REDIS
      
      REDIS.setex('trial_balance:current', 5.minutes.to_i, trial_balance.to_json)
    rescue Redis::BaseError
      # Silent fail
    end
  end
end