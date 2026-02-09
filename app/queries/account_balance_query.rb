# app/queries/account_balance_query.rb
#
# Query class for retrieving account balances
# Supports current and historical balance queries with caching

class AccountBalanceQuery
  class << self
    # Get current balance for a single account
    def current(account_id)
      account = Account.find(account_id)
      balance = account.current_balance_cached
      
      format_balance(account, balance)
    end
    
    # Get historical balance for a single account
    def historical(account_id, as_of_date)
      account = Account.find(account_id)
      balance = account.balance(as_of: as_of_date)
      
      format_balance(account, balance, as_of_date)
    end
    
    # Get current balances for multiple accounts (bulk operation)
    def bulk_current(account_ids)
      accounts = Account.where(id: account_ids).index_by(&:id)
      
      # Try to get all from Redis in one pipeline
      balances = {}
      cache_misses = []
      
      begin
        account_versions = accounts.map { |id, acc| [id, acc.lock_version] }
        cached_balances = BalanceCache.bulk_get(account_versions.to_h)
        
        account_ids.each do |account_id|
          account = accounts[account_id]
          
          if cached_balances[account_id]
            balances[account_id] = cached_balances[account_id]
          else
            balances[account_id] = account.current_balance
            cache_misses << [account_id, account.lock_version, account.current_balance]
          end
        end
        
        BalanceCache.bulk_set(cache_misses) if cache_misses.any?
        
      rescue => e
        Rails.logger.error("Bulk cache fetch failed: #{e.message}")
        accounts.each { |id, account| balances[id] = account.current_balance }
      end
      
      account_ids.map { |id| format_balance(accounts[id], balances[id]) }
    end
    
    # Get balances for all accounts of a specific type
    def by_type(account_type, currency: nil)
      scope = Account.active.by_type(account_type)
      scope = scope.by_currency(currency) if currency
      
      accounts = scope.with_balance.order(:code)
      accounts.map { |account| format_balance(account, account.current_balance) }
    end
    
    # Get balance summary grouped by account type
    def summary_by_type(currency: nil)
      scope = Account.active
      scope = scope.by_currency(currency) if currency
      
      summary = scope.group(:account_type)
                    .select('account_type, SUM(current_balance) as total_balance, COUNT(*) as account_count')
                    .map do |result|
                      {
                        account_type: result.account_type,
                        total_balance: result.total_balance.to_f,
                        account_count: result.account_count
                      }
                    end
      
      { currency: currency || 'ALL', summary: summary, generated_at: Time.current }
    end
    
    private
    
    def format_balance(account, balance, as_of = Time.current)
      {
        account_id: account.id,
        account_code: account.code,
        account_name: account.name,
        account_type: account.account_type,
        currency: account.currency,
        balance: balance.to_f,
        as_of: as_of
      }
    end
  end
end
