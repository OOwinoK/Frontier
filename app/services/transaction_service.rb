class TransactionService
  class TransactionError < StandardError; end
  class UnbalancedTransactionError < TransactionError; end
  class IdempotencyError < TransactionError; end
  class ValidationError < TransactionError; end
  
  attr_reader :transaction, :errors
  
  def initialize
    @errors = []
  end
  
  def create_transaction(idempotency_key:, description:, entries:, posted_at: nil, metadata: {})
    existing = Transaction.find_by(idempotency_key: idempotency_key)
    return existing if existing

    validate_entries!(entries)
    validate_balance!(entries)
    
    account_ids = entries.map { |e| (e[:account_id] || e['account_id']) }.uniq.sort

    # Use a single DB transaction block to ensure Atomicity
    ActiveRecord::Base.transaction do
      # Lock accounts in fixed order to prevent deadlocks
      accounts = Account.where(id: account_ids).lock('FOR UPDATE').order(:id).index_by(&:id)
      validate_accounts_exist!(account_ids, accounts)

      @transaction = Transaction.new(
        idempotency_key: idempotency_key,
        description: description,
        posted_at: posted_at || Time.current,
        status: 'posted',
        metadata: metadata
      )

      entries.each do |entry_params|
        e = entry_params.is_a?(Hash) ? entry_params : entry_params.to_h
        account = accounts[e[:account_id] || e['account_id']]
        
        debit = (e[:debit] || e['debit']).to_f
        credit = (e[:credit] || e['credit']).to_f

        # Build entry attributes (ignoring 0.0 values)
        attrs = {
          account: account,
          description: e[:description] || e['description']
        }
        attrs[:debit] = debit if debit > 0
        attrs[:credit] = credit if credit > 0
        
        @transaction.entries.build(attrs)

        # Update Account Balance inside the SAME transaction block
        # This ensures that if @transaction.save! fails, the balance update rolls back.
        update_account_balance(account, debit, credit)
      end

      # If any part of this fails, everything above rolls back
      @transaction.save!
      cache_transaction_idempotency(idempotency_key, @transaction.id)
    end
    
    after_transaction_created(account_ids)
    @transaction
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError, e.message
  rescue => e
    # Log and re-raise to ensure the DB transaction rolls back
    Rails.logger.error("TransactionService error: #{e.message}")
    raise e
  end

  def void_transaction(transaction)
    raise ValidationError, 'Cannot void non-posted transaction' unless transaction.posted?
    transaction.void!
    transaction
  end
  
  def reverse_transaction(transaction)
    raise ValidationError, 'Cannot reverse non-posted transaction' unless transaction.posted?
    transaction.reverse!
    transaction
  end

  private

  # This logic addresses the SIGNAGE issue (Accounting Normal Balances)
  def update_account_balance(account, debit, credit)
    change_amount = 0
    
    # ASSET and EXPENSE: Normal Debit Balance (Debit increases, Credit decreases)
    # LIABILITY, EQUITY, INCOME: Normal Credit Balance (Credit increases, Debit decreases)
    if ['ASSET', 'EXPENSE'].include?(account.account_type.to_s.upcase)
      change_amount = debit - credit
    else
      change_amount = credit - debit
    end

    # Use update! to ensure we are inside the transaction and validations are checked
    account.update!(current_balance: account.current_balance + change_amount)
  end

  def validate_entries!(entries)
    raise ValidationError, 'Transaction must have at least two entries' if entries.blank? || entries.size < 2
  end
  
  def validate_balance!(entries)
    total_debits = entries.sum { |e| (e[:debit] || e['debit'] || 0).to_f }.round(4)
    total_credits = entries.sum { |e| (e[:credit] || e['credit'] || 0).to_f }.round(4)
    
    if (total_debits - total_credits).abs > 0.0001
      raise UnbalancedTransactionError, "Transaction must balance. Debits: #{total_debits}, Credits: #{total_credits}"
    end
  end
  
  def validate_accounts_exist!(account_ids, accounts)
    missing_ids = account_ids - accounts.keys
    raise ValidationError, "Accounts not found: #{missing_ids.join(', ')}" if missing_ids.any?
  end

  def cache_transaction_idempotency(key, id)
    return unless defined?(REDIS)
    REDIS.setex("txn:idem:#{key}", 24.hours.to_i, id)
  end
  
  def after_transaction_created(account_ids)
    # Hooks for cache invalidation or background jobs
  end
end