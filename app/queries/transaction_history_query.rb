# app/queries/transaction_history_query.rb
#
# Query class for retrieving transaction history
# Supports pagination, filtering, and running balance calculation

class TransactionHistoryQuery
  PER_PAGE = 50
  
  class << self
    # Get transaction history for an account with pagination
    def for_account(account_id, page: 1, per_page: PER_PAGE, start_date: nil, end_date: nil)
      account = Account.find(account_id)
      
      # Convert params to proper types
      page = page.to_i
      per_page = per_page.to_i
      per_page = PER_PAGE if per_page <= 0
      
      # Build base query - Use 'txn' to match Entry model association
      entries = Entry.includes(:txn)
                    .where(account_id: account_id)
                    .order(created_at: :desc)
      
      # Apply date filters
      entries = entries.where('entries.created_at >= ?', start_date) if start_date
      entries = entries.where('entries.created_at <= ?', end_date) if end_date
      
      # Get total count for pagination
      total_count = entries.count
      total_pages = (total_count.to_f / per_page).ceil
      
      # Paginate
      entries = entries.limit(per_page).offset((page - 1) * per_page)
      
      # Calculate starting balance for this page
      starting_balance = calculate_starting_balance(account_id, entries.last&.created_at, start_date)
      
      # Build transaction list with running balance
      transactions = build_transaction_list(entries, starting_balance)
      
      {
        account_id: account_id,
        account_name: account.name,
        account_code: account.code,
        currency: account.currency,
        current_balance: account.current_balance.to_f,
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        transactions: transactions,
        date_range: {
          start_date: start_date,
          end_date: end_date
        }
      }
    end
    
    # Get all transactions (across all accounts) with pagination
    def all_transactions(page: 1, per_page: PER_PAGE, start_date: nil, end_date: nil, status: nil)
      # Convert params to proper types
      page = page.to_i
      per_page = per_page.to_i
      per_page = PER_PAGE if per_page <= 0
      
      scope = Transaction.includes(:entries, :accounts).order(posted_at: :desc)
      
      scope = scope.where('posted_at >= ?', start_date) if start_date
      scope = scope.where('posted_at <= ?', end_date) if end_date
      scope = scope.where(status: status) if status
      
      total_count = scope.count
      total_pages = (total_count.to_f / per_page).ceil
      
      transactions = scope.limit(per_page).offset((page - 1) * per_page)
      
      {
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        transactions: transactions.map { |txn| format_transaction(txn) }
      }
    end
    
    # Search transactions by description or reference
    def search(query, page: 1, per_page: PER_PAGE)
      # Convert params to proper types
      page = page.to_i
      per_page = per_page.to_i
      per_page = PER_PAGE if per_page <= 0
      
      scope = Transaction.includes(:entries, :accounts)
                        .where("description ILIKE ? OR external_reference ILIKE ?", "%#{query}%", "%#{query}%")
                        .order(posted_at: :desc)
      
      total_count = scope.count
      total_pages = (total_count.to_f / per_page).ceil
      
      transactions = scope.limit(per_page).offset((page - 1) * per_page)
      
      {
        query: query,
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        transactions: transactions.map { |txn| format_transaction(txn) }
      }
    end
    
    private
    
    def calculate_starting_balance(account_id, before_date, filter_start_date)
      return 0 unless before_date
      
      account = Account.find(account_id)
      
      # Use snapshot if available for performance
      snapshot = account.balance_snapshots
                       .where('snapshot_date < ?', before_date.to_date)
                       .order(snapshot_date: :desc)
                       .first
      
      if snapshot
        # Balance from snapshot + entries between snapshot and before_date
        delta = Entry.where(account_id: account_id)
                    .where('created_at > ? AND created_at < ?', 
                           snapshot.snapshot_date.end_of_day, 
                           before_date)
        
        # Apply filter start date if present
        delta = delta.where('created_at >= ?', filter_start_date) if filter_start_date
        
        delta_amount = delta.sum('COALESCE(debit, 0) - COALESCE(credit, 0)').to_f
        snapshot.balance.to_f + delta_amount
      else
        # No snapshot - calculate from beginning
        scope = Entry.where(account_id: account_id).where('created_at < ?', before_date)
        scope = scope.where('created_at >= ?', filter_start_date) if filter_start_date
        scope.sum('COALESCE(debit, 0) - COALESCE(credit, 0)').to_f
      end
    end
    
    def build_transaction_list(entries, starting_balance)
      running_balance = starting_balance.to_f
      
      # Reverse to calculate balance forward (oldest to newest)
      entries.reverse.map do |entry|
        amount = (entry.debit || 0) - (entry.credit || 0)
        running_balance += amount
        
        {
          id: entry.id,
          transaction_id: entry.transaction_id,
          date: entry.created_at,
          description: entry.txn.description,
          entry_description: entry.description,
          debit: entry.debit&.to_f,
          credit: entry.credit&.to_f,
          amount: amount.abs.to_f,
          type: entry.debit? ? 'debit' : 'credit',
          balance: running_balance.to_f,
          idempotency_key: entry.txn.idempotency_key,
          status: entry.txn.status
        }
      end.reverse # Return in desc order (newest first)
    end
    
    def format_transaction(transaction)
      {
        id: transaction.id,
        idempotency_key: transaction.idempotency_key,
        description: transaction.description,
        posted_at: transaction.posted_at,
        status: transaction.status,
        total_debits: transaction.total_debits&.to_f,
        total_credits: transaction.total_credits&.to_f,
        balanced: transaction.balanced?,
        entries: transaction.entries.map do |entry|
          {
            id: entry.id,
            account_code: entry.account.code,
            account_name: entry.account.name,
            debit: entry.debit&.to_f,
            credit: entry.credit&.to_f
          }
        end
      }
    end
  end
end